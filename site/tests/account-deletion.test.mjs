import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { deletionStatements } from '../src/lib/account-deletion.ts';

const db = new DatabaseSync(':memory:');
db.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
db.exec(`PRAGMA foreign_keys=ON;
  INSERT INTO users(id,handle,email) VALUES(1,'delete_me','one@example.test'),(2,'keep_me','two@example.test');
  INSERT INTO residents(id,handle,tier) VALUES(0,'mod','admin');
  INSERT INTO posts(id,user_id,kind,title,body) VALUES(1,1,'human','own','body'),(2,2,'human','keep','body');
  INSERT INTO comments(id,post_id,user_id,body,parent_id) VALUES(1,2,1,'own comment',NULL),(2,2,2,'keep reply',1),(3,1,2,'on deleted post',NULL);
  INSERT INTO reports(comment_id) VALUES(1),(3);
  INSERT INTO sessions VALUES('session',1,datetime('now','+1 day'));
  INSERT INTO auth_tokens VALUES('verify',1,'verify',datetime('now','+1 day'));
  INSERT INTO account_deletions VALUES('valid',1,datetime('now','+1 day')),('expired',2,datetime('now','-1 day'));
  INSERT INTO poll_options(id,post_id,label) VALUES(1,1,'option');
  INSERT INTO poll_votes VALUES(2,1,1);
  INSERT INTO likes(user_id,post_id) VALUES(1,2),(2,1);
  INSERT INTO dms(thread,from_user_id,to_user_id,body) VALUES('u1|u2',1,2,'private');
  INSERT INTO user_blocks(user_id,target_type,target_id) VALUES(2,'user',1);
  INSERT INTO safety_reports(user_id,target_type,target_id,reason) VALUES(1,'post',2,'test');`);
function run(token) {
  db.exec('BEGIN');
  try { for (const sql of deletionStatements) db.prepare(sql).run(token); db.exec('COMMIT'); }
  catch (error) { db.exec('ROLLBACK'); throw error; }
}
run('expired');
assert.equal(db.prepare('SELECT COUNT(*) n FROM users').get().n,2);
run('valid');
assert.deepEqual(db.prepare('SELECT id FROM users').all().map(row=>row.id),[2]);
assert.equal(db.prepare('SELECT COUNT(*) n FROM posts').get().n,1);
assert.equal(db.prepare('SELECT COUNT(*) n FROM sessions').get().n,0);
assert.equal(db.prepare('SELECT COUNT(*) n FROM dms').get().n,0);
assert.equal(db.prepare('SELECT parent_id FROM comments WHERE id=2').get().parent_id,null);
assert.equal(db.prepare('SELECT COUNT(*) n FROM user_blocks').get().n,0);
run('valid');
assert.equal(db.prepare('SELECT COUNT(*) n FROM users').get().n,1);
assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(),[]);
db.close();
console.log('PASS deletion: expired token, FK cleanup, survivor data, replay');
