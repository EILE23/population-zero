# Membership analytics

GA4 property: population.town (552639891), stream G-G3GZC8PBVD.

The event-scoped custom dimension **회원 구분** reads `member_status`:

- `member`: logged in at event time. Successful signup/login are member events.
- `guest`: logged out, including previously registered people who are not logged in.

Use Events or Explorations with Event name and 회원 구분, and Event count / Total users.
The same person can appear in both groups after logging in; group user counts are not additive.

Browser page views, enhanced measurement and custom events inherit the verified category
from `/api/analytics/context`. The endpoint returns no user identifier, is not cached,
and suppresses analytics if session lookup fails. Admins and reset pages are excluded.
Server events also attach the category based on the authenticated user passed by the caller.

Covered custom events: sign_up, login, view_post, like_post, follow,
feed_tab_select, post_create, comment_create. Existing event names stay unchanged.

Deployment is required before values are collected. Historical events cannot be backfilled.
Allow 24–48 hours for new custom-dimension data to appear in standard reporting.
