// Execute the real route and SQL against in-memory SQLite; external services are mocked.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');
const { stripTypeScriptTypes } = require('node:module');
function load(path, mocks, globals = {}) {
  const source = fs.readFileSync(path, 'utf8');
  // These modules use named imports/exports only. Strip types, then bind imports to test doubles.
  const names = [];
  const js = stripTypeScriptTypes(source)
    .replace(/import\s*\{([^}]+)\}\s*from\s*['"]([^'"]+)['"];?/g, (_, bindings, id) => 'const {' + bindings + '} = require(' + JSON.stringify(id) + ');')
    .replace(/export\s+(async\s+)?(function|const)\s+(\w+)/g, (_, async, kind, name) => { names.push(name); return (async || '') + kind + ' ' + name; })
    + '\n' + names.map(name => 'exports.' + name + ' = ' + name + ';').join('\n');
  const exports = {};
  vm.runInNewContext(js, { exports, require: id => { if (!(id in mocks)) throw Error('Unexpected import: '+id); return mocks[id]; }, console, Date, URL, URLSearchParams, Request, Response, AbortSignal, TextEncoder, Uint8Array, ArrayBuffer, process: { env: {} }, ...globals }, { filename: path });
  return exports;
}
// D1 accepts numbered placeholders (?1 reused several times, bound once). node:sqlite does not —
// it counts every occurrence as its own parameter and throws "column index out of range".
// Expand them to plain ? with repeated arguments so the harness matches D1's behaviour.
function expand(sql, args) {
  if (!/\?\d/.test(sql)) return [sql, args];
  const expanded = [];
  const out = sql.replace(/\?(\d+)/g, (_, n) => { expanded.push(args[Number(n) - 1]); return '?'; });
  return [out, expanded];
}
function adapter(db) {
  return { prepare(sql) { return { bind(...args) { const [q, a] = expand(sql, args); return { async first() { return db.prepare(q).get(...a) ?? null; }, async run() { const result=db.prepare(q).run(...a); return { meta: {last_row_id:Number(result.lastInsertRowid), changes:Number(result.changes)} }; } }; } }; } };
}
const results=[];
async function check(name, test) { await test(); results.push({name, passed:true}); console.log('PASS:',name); }
(async()=>{
  function google(db) {
    return load('site/src/app/api/auth/google/callback/route.ts', {
      'next/navigation':{redirect: url=>{throw Error('REDIRECT '+url);}},
      'next/headers':{cookies:async()=>({get:()=>({value:'state'}),delete(){}})},
      '@/lib/db':{getDb:async()=>adapter(db),getEnv:async()=>({})},
      '@/lib/auth':{createSession:async()=>{}}, '@/lib/seo':{SITE_URL:'https://example.test'}, '@/lib/ga-mp':{fireGaEvent:async()=>{}},
    },{fetch:async url=>Response.json(String(url).includes('/token')?{access_token:'fake'}:{sub:'google-sub',email:'member@example.test',name:'resident'})});
  }
  function database() { const db=new DatabaseSync(':memory:'); db.exec('CREATE TABLE users(id INTEGER PRIMARY KEY,handle TEXT UNIQUE,email TEXT UNIQUE,google_sub TEXT,email_verified INTEGER); CREATE TABLE residents(id INTEGER PRIMARY KEY,handle TEXT)'); return db; }
  await check('Google signup avoids resident handle collisions',async()=>{
    const db=database(); db.exec("INSERT INTO residents VALUES(1,'resident')");
    await assert.rejects(google(db).GET(new Request('https://example.test/api/auth/google/callback?code=fake&state=state')),/REDIRECT/);
    assert.equal(db.prepare("SELECT handle FROM users").get().handle,'resident2');
    db.close();
  });
  await check('Existing local email redirects to original login',async()=>{
    const db=database(); db.exec("INSERT INTO users(handle,email) VALUES('localuser','member@example.test')");
    await assert.rejects(google(db).GET(new Request('https://example.test/api/auth/google/callback?code=fake&state=state')),/REDIRECT \/login\?error=google_existing_email/); db.close();
  });
  await check('Expired ISO sessions are rejected; future sessions work',async()=>{
    const db=new DatabaseSync(':memory:');
    db.exec('CREATE TABLE users(id,handle,email,google_sub,is_admin,bio,blog_title,email_verified,handle_picked,avatar_url); CREATE TABLE sessions(token,user_id,expires_at); INSERT INTO users(id) VALUES(1)');
    const expired = new Date(Date.now()-1000).toISOString();
    db.prepare('INSERT INTO sessions VALUES(?,?,?)').run('expired-token',1,expired);
    assert.equal(db.prepare("SELECT julianday(?) < julianday('now') AS expired").get(expired).expired,1);
    const auth=load('site/src/lib/auth.ts',{'react':{cache:fn=>fn},'next/headers':{cookies:async()=>({get:()=>({value:'expired-token'})})},'./db':{getDb:async()=>adapter(db)}});
    assert.equal(await auth.getSessionUser(),null); db.prepare('UPDATE sessions SET expires_at = ?').run(new Date(Date.now()+60000).toISOString()); assert.equal((await auth.getSessionUser()).id,1); db.close();
  });
  await check('Existing tab refreshes classification without duplicate pageviews',async()=>{
    const {GA_BOOTSTRAP}=load('site/src/lib/ga-bootstrap.ts',{});
    let member=false,requests=0; const listeners={}; const window={addEventListener:(name, fn)=>{listeners[name]=fn;}};
    vm.runInNewContext(GA_BOOTSTRAP,{window,document:{cookie:''},location:{pathname:'/'},AbortSignal,fetch:async()=>{requests++;return Response.json({member_status:member?'member':'guest',excluded:false});}});
    await new Promise(r=>setImmediate(r)); member=true; listeners.focus(); await new Promise(r=>setImmediate(r));
    window.gtag('event','like_post',{post_id:1});
    assert.equal(requests,2); const configs=window.dataLayer.filter(args=>args[0]==='config'); assert.equal(configs[1][2].member_status,'member'); assert.equal(configs[1][2].send_page_view,false); member=false; listeners.focus(); await new Promise(r=>setImmediate(r)); assert.equal(window.dataLayer.filter(args=>args[0]==='config').at(-1)[2].member_status,'guest');
  });
  await check('First admin login is excluded even without exclusion cookie',async()=>{
    const sent=[]; let sessionCreated=false, isAdmin=1;
    const {fireGaEvent}=load('site/src/lib/ga-mp.ts',{'@/lib/db':{getEnv:async()=>({GA_MP_SECRET:'fake'}),getDb:async()=>({prepare:()=>({bind:()=>({first:async()=>({is_admin:isAdmin})})})})}},{fetch:async(u,opts)=>{sent.push({sessionCreated,body:JSON.parse(opts.body)});return new Response(null,{status:204});}});
    const route=load('site/src/app/api/auth/login/route.ts',{
      'next/navigation':{redirect:u=>{throw Error('REDIRECT '+u);}},
      '@/lib/db':{getDb:async()=>({prepare:()=>({bind:()=>({first:async()=>({id:1,password_hash:'fake',is_admin:1})})})})},
      '@/lib/ratelimit':{authRateLimited:async()=>false},
      '@/lib/auth':{verifyPassword:async()=>true,createSession:async()=>{sessionCreated=true;}},
      '@/lib/ga-mp':{fireGaEvent},
    });
    const request=new Request('https://example.test/api/auth/login',{method:'POST',headers:{cookie:'_ga=GA1.1.123.456','content-type':'application/x-www-form-urlencoded'},body:'handle=admin&password=fake'});
    await assert.rejects(route.POST(request),/REDIRECT/);
    assert.equal(sent.length,0); assert.equal(sessionCreated,true); isAdmin=0; await fireGaEvent('login',request,{},1); assert.equal(sent.length,1); assert.equal(sent[0].body.events[0].params.member_status,'member');
  });
})().catch(e=>{console.error(e);process.exitCode=1;});
