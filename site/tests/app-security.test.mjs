import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { stripTypeScriptTypes } from 'node:module';

const db = new DatabaseSync(':memory:');
db.exec(fs.readFileSync('site/schema.sql', 'utf8'));
db.exec("INSERT INTO users(id,handle,email_verified) VALUES(1,'alice',1),(2,'bob',1),(3,'eve',1)");
const DB = { prepare(sql) { return { bind(...args) {
  let values=args;
  if (/\?\d/.test(sql)) { values=[]; sql=sql.replace(/\?(\d+)/g,(_,n)=>{values.push(args[+n-1]);return '?';}); }
  return { first:async()=>db.prepare(sql).get(...values), run:async()=>db.prepare(sql).run(...values) };
} }; } };
const load = (path, context, name) => {
  const js=stripTypeScriptTypes(fs.readFileSync(path,'utf8')).replace(/import[^;]+;/g,'').replaceAll('export ','');
  vm.runInNewContext(js+`\nthis.result=${name};`,context); return context.result;
};
const shared={Request,Response,URL,TextEncoder,Uint8Array,crypto:webcrypto,getDb:async()=>DB};
const safety={...shared};
load('site/src/lib/safety.ts',safety,'isBlocked');
const exchange=load('site/src/app/api/auth/app-exchange/route.ts',{...shared,authRateLimited:async()=>false,createSessionToken:async id=>`session-${id}`},'POST');
const verifier='b'.repeat(64), code='a'.repeat(32);
const digest=await webcrypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier));
const challenge=Buffer.from(digest).toString('hex');
const seed=expiry=>db.prepare('INSERT INTO app_login_codes VALUES(?,?,?,?)').run(code,1,challenge,expiry);
const call=v=>exchange(new Request('https://population.town/api/auth/app-exchange',{method:'POST',body:JSON.stringify({code,verifier:v})}));
seed('2099-01-01 00:00:00');
assert.equal((await call('c'.repeat(64))).status,401);
assert.equal((await (await call(verifier)).json()).token,'session-1');
assert.equal((await call(verifier)).status,401);
seed('2000-01-01 00:00:00'); assert.equal((await call(verifier)).status,401);
console.log('PASS app sign-in: wrong verifier, valid exchange, replay and expiry');

db.exec("INSERT INTO dms(id,thread,from_user_id,to_user_id,body) VALUES(1,'u1|u2',1,2,'photo')");
db.prepare('INSERT INTO dm_images VALUES(?,?,?,?)').run('private',1,'image/png',new Uint8Array([137,80,78,71]));
let viewer=null;
const image=load('site/src/app/api/dm/image/[id]/route.ts',{...shared,getSessionUser:async()=>viewer,isBlocked:safety.isBlocked,otherParty:(_,me)=>({kind:'user',id:me.id===1?2:1})},'GET');
const read=()=>image(new Request('https://population.town/api/dm/image/private'),{params:Promise.resolve({id:'private'})});
assert.equal((await read()).status,401);
viewer={id:3}; assert.equal((await read()).status,404);
viewer={id:2}; const allowed=await read();assert.equal(allowed.status,200);assert.equal(allowed.headers.get('cache-control'),'private, no-store');assert.equal((await allowed.arrayBuffer()).byteLength,4);
db.exec("INSERT INTO user_blocks VALUES(1,'user',2,datetime('now'))");assert.equal((await read()).status,404);
db.exec('DELETE FROM dms WHERE id=1');assert.equal(db.prepare('SELECT COUNT(*) n FROM dm_images').get().n,0);
assert.equal(safety.sameOriginOrBearer(new Request('https://population.town/test',{headers:{cookie:'pz_session=valid',authorization:'Bearer fake',origin:'https://evil.test'}})),false);
console.log('PASS private photos: anonymous/outsider denied, participant allowed, block denied, deletion cascades; cookie CSRF rejected');
db.close();
