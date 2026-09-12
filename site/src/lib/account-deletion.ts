// Each statement resolves the still-valid one-time token inside the same D1 batch.
// Concurrent confirmations therefore cannot delete a different/recreated account.
export const deletionStatements = [
  `UPDATE comments SET parent_id=NULL WHERE parent_id IN (SELECT id FROM comments WHERE user_id=UID OR post_id IN (SELECT id FROM posts WHERE user_id=UID))`,
  `DELETE FROM reports WHERE comment_id IN (SELECT id FROM comments WHERE user_id=UID OR post_id IN (SELECT id FROM posts WHERE user_id=UID))`,
  `DELETE FROM comment_decisions WHERE comment_id IN (SELECT id FROM comments WHERE user_id=UID OR post_id IN (SELECT id FROM posts WHERE user_id=UID))`,
  `DELETE FROM comments WHERE user_id=UID OR post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM poll_votes WHERE user_id=UID OR post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM resident_poll_votes WHERE post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM poll_options WHERE post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM likes WHERE user_id=UID OR post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM resident_likes WHERE post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM post_images WHERE post_id IN (SELECT id FROM posts WHERE user_id=UID)`,
  `DELETE FROM posts WHERE user_id=UID`,
  `DELETE FROM dms WHERE from_user_id=UID OR to_user_id=UID`,
  `DELETE FROM room_messages WHERE user_id=UID`,
  `DELETE FROM trend_events WHERE user_id=UID`,
  `DELETE FROM follows WHERE (follower_type='user' AND follower_id=UID) OR (target_type='user' AND target_id=UID)`,
  `DELETE FROM follow_events WHERE (follower_type='user' AND follower_id=UID) OR (target_type='user' AND target_id=UID)`,
  `DELETE FROM user_blocks WHERE user_id=UID OR (target_type='user' AND target_id=UID)`,
  `DELETE FROM safety_reports WHERE user_id=UID`,
  `DELETE FROM auth_tokens WHERE user_id=UID`,
  `DELETE FROM sessions WHERE user_id=UID`,
  // The confirmation table deliberately releases its FK before deleting users.
  `DELETE FROM account_deletions WHERE user_id=UID AND token<>?1`,
  `DELETE FROM users WHERE id=UID`,
  `DELETE FROM account_deletions WHERE token=?1`,
].map(sql => sql.replaceAll('UID', `(SELECT user_id FROM account_deletions WHERE token=?1 AND expires_at>datetime('now'))`));
