import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { stripTypeScriptTypes } from 'node:module';

const db = new DatabaseSync(':memory:');
const schema = fs.readFileSync('site/schema.sql', 'utf8');
db.exec(schema); db.exec(schema);
console.log('PASS schema initializes twice');
db.exec(`INSERT INTO users(id,handle,email_verified) VALUES(1,'alice',1),(2,'bob',1);`);
db.prepare('INSERT INTO sessions(token,user_id,expires_at) VALUES(?,?,?)').run('valid',1,new Date(Date.now()+3600000).toISOString());
const DB = { prepare(sql) { return { bind(...args) {
  let params = args;
  if (/\?\d/.test(sql)) { params=[]; sql=sql.replace(/\?(\d+)/g,(_,n)=>{params.push(args[+n-1]);return '?';}); }
  return { all:async()=>({results:db.prepare(sql).all(...params)}), first:async()=>db.prepare(sql).get(...params), run:async()=>{
    const r=db.prepare(sql).run(...params); return {meta:{changes:Number(r.changes),last_row_id:Number(r.lastInsertRowid)}};
  }};
}}; }};
const src=fs.readFileSync('site/chat-room.js','utf8').replace("import { DurableObject } from 'cloudflare:workers';",'').replace('export class ChatRoom','class ChatRoom')+'\nthis.ChatRoom=ChatRoom;';
const sandbox={DurableObject:class {constructor(ctx,env){this.ctx=ctx;this.env=env;}},Response,Request,URL};
vm.runInNewContext(src,sandbox);
const sent=[];let closed=0;
const peer={deserializeAttachment:()=>({thread:'u1|u2',userId:1,token:'valid',ip:'test-ip'}),send:m=>sent.push(JSON.parse(m)),close:()=>closed++};
const room=new sandbox.ChatRoom({getWebSockets:()=>[peer]},{DB});
db.exec('UPDATE users SET email_verified=0 WHERE id=1');
await room.webSocketMessage(peer,JSON.stringify({body:'blocked'}));
assert.equal(closed,1);assert.equal(db.prepare('SELECT COUNT(*) n FROM dms').get().n,0);
db.exec('UPDATE users SET email_verified=1 WHERE id=1');
for(let i=0;i<31;i++) await room.webSocketMessage(peer,JSON.stringify({body:'allowed'}));
assert.equal(db.prepare('SELECT COUNT(*) n FROM dms').get().n,30);
assert.equal(sent.at(-1).error,'rate');
console.log('PASS socket verification and 30/5min limit');
db.exec("DELETE FROM sessions WHERE token='valid'");
await room.webSocketMessage(peer,JSON.stringify({body:'revoked'}));
assert.equal(closed,2);
console.log('PASS revoked session cannot keep sending');
const r=db.prepare('INSERT INTO dms(thread,from_user_id,to_user_id,body,image) VALUES(?,?,?,?,?)').run('u1|u2',2,1,'','https://example.test/photo.png');
await room.fetch(new Request(`https://room.internal/notify?thread=u1%7Cu2&id=${r.lastInsertRowid}`,{method:'POST'}));
assert.equal(closed,3); // Revoked recipients must not receive HTTP broadcasts either.
db.prepare('INSERT INTO sessions(token,user_id,expires_at) VALUES(?,?,?)').run('valid',1,new Date(Date.now()+3600000).toISOString());
await room.fetch(new Request(`https://room.internal/notify?thread=u1%7Cu2&id=${r.lastInsertRowid}`,{method:'POST'}));
assert.equal(sent.at(-1).message.image,'https://example.test/photo.png'); assert.equal(sent.at(-1).mine,false);
console.log('PASS HTTP photo notification reaches authenticated peer only');
db.exec("INSERT INTO user_blocks(user_id,target_type,target_id) VALUES(2,'user',1)");
const beforeBlock=sent.length;
await room.fetch(new Request(`https://room.internal/notify?thread=u1%7Cu2&id=${r.lastInsertRowid}`,{method:'POST'}));
assert.equal(sent.length,beforeBlock);
await room.webSocketMessage(peer,JSON.stringify({body:'blocked reply'}));
assert.equal(sent.length,beforeBlock);
db.exec('DELETE FROM user_blocks');
console.log('PASS block stops existing socket delivery and sending');

// Exercise the real hook with deterministic network/timer/lifecycle boundaries.
let state, cleanup, effect, socket;
const timers=[];const calls=[];
let messages=Array.from({length:451},(_,i)=>({id:i+1,body:String(i),mine:false,read:false}));
const react={useState:initial=>{state=initial;return [state,update=>{state=typeof update==='function'?update(state):update;}];},useRef:value=>({current:value}),useCallback:f=>f,useEffect:f=>{effect=f;}};
const api={API_BASE:'https://example.test',getToken:async()=> 'token',fetchThread:async(thread,after)=>{calls.push(after);return {live:true,messages:messages.filter(m=>m.id>after).slice(0,200)};},sendDm:async()=>{messages.push({id:messages.length+1,body:'sent',mine:true,read:false});}};
let js=stripTypeScriptTypes(fs.readFileSync('app/src/hooks/useChat.ts','utf8')).replace(/import\s*\{[^}]+\}\s*from 'react';/, 'const {useState,useRef,useEffect,useCallback}=react;').replace(/import\s*\{[^}]+\}\s*from '@\/api';/,'const {API_BASE,fetchThread,getToken,sendDm}=api;').replace('export function useChat','function useChat')+'\nthis.useChat=useChat;';
const hooks={react,api,WebSocket:class {constructor(){socket=this;}close(){}},setTimeout:f=>{timers.push(f);return timers.length;},clearTimeout:()=>{}};
vm.runInNewContext(js,hooks);
const hook=hooks.useChat('u1|u2','user');cleanup=effect();
const flush=()=>new Promise(r=>setImmediate(r));await flush();
assert.equal(state.messages.length,451);assert.ok(calls.includes(200)&&calls.includes(400));
socket.onopen(); await flush();
messages.push({id:452,body:'http photo',mine:false,read:false});
await timers.shift()();await flush();assert.equal(state.messages.length,452);
await hook.send('bob','sent');await flush();assert.equal(state.messages.length,453);
console.log('PASS 451-message history, polling while connected, HTTP send');
cleanup();messages.push({id:454,body:'late'});socket.onmessage();await flush();assert.equal(state.messages.length,453);
console.log('PASS late socket callback cannot update closed conversation');
// Run the edge handshake itself: malformed threads, expiry and unverified accounts.
let forwarded=0;
let edge=fs.readFileSync('site/worker-entry.js','utf8')
  .replace(/import handler[^;]+;/,'').replace(/import \{ cleanupAssets \}[^;]+;/,'')
  .replace(/export \{[^}]+\} from [^;]+;/g,'')
  .replace('export default {','this.worker = {');
const edgeContext={Response,Request,URL,console,handler:{fetch:async()=>new Response('ok')}};
vm.runInNewContext(edge,edgeContext);
const env={DB,CHAT_ROOM:{idFromName:t=>t,get:()=>({fetch:async()=>{forwarded++;return new Response('forwarded');}})}};
const open=thread=>edgeContext.worker.fetch(new Request(`https://example.test/ws/dm?thread=${encodeURIComponent(thread)}&token=valid`),env,{});
db.prepare('UPDATE sessions SET expires_at=? WHERE token=?').run(new Date(Date.now()-1000).toISOString(),'valid');
assert.equal((await open('u1|u2')).status,401);
db.prepare('UPDATE sessions SET expires_at=?').run(new Date(Date.now()+3600000).toISOString());
db.exec('UPDATE users SET email_verified=0 WHERE id=1');assert.equal((await open('u1|u2')).status,403);
db.exec('UPDATE users SET email_verified=1 WHERE id=1');
for(const bad of ['u1|u2|u3','u2|u1','u1|u1','u1|u999','u2|u3']) assert.equal((await open(bad)).status,404);
assert.equal(forwarded,0);assert.equal((await open('u1|u2')).status,200);assert.equal(forwarded,1);
console.log('PASS edge rejects expired, unverified and invalid conversation access');

let route=stripTypeScriptTypes(fs.readFileSync('site/src/app/api/dm/[thread]/route.ts','utf8'))
  .replace(/import[^;]+;/g,'').replace('export async function GET','async function GET')+'\nthis.GET=GET;';
const routeContext={Response,URL,getSessionUser:async()=>({id:1}),getDb:async()=>DB,
 threadParties:t=>t.split('|').map(p=>({kind:p[0]==='u'?'user':'resident',id:Number(p.slice(1))})),
 otherParty:()=>({kind:'user',id:2})};
const safety=stripTypeScriptTypes(fs.readFileSync('site/src/lib/safety.ts','utf8')).replace(/import[^;]+;/g,'').replaceAll('export ','');
vm.runInNewContext(safety+'\nthis.isBlocked=isBlocked;',routeContext);
vm.runInNewContext(route,routeContext);
const before=Number(r.lastInsertRowid);
const response=await routeContext.GET(new Request(`https://example.test/api/dm/u1%7Cu2?before=${before}`),{params:Promise.resolve({thread:'u1%7Cu2'})});
assert.equal(response.status,200);
const history=(await response.json()).messages;
assert.equal(history.length,30);assert.ok(history.every(m=>m.id<before));assert.ok(history[0].id<history.at(-1).id);
console.log('PASS encoded web thread loads earlier messages in chronological order');
db.close();
