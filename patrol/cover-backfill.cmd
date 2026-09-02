@echo off
rem 일회성: 커버 없는 기존 글 전체에 일러스트 커버 소급 (glLM이 글을 읽고 프롬프트 결정)
cd /d C:\works\zavis\ideas\yarmeal
set LOGDIR=C:\works\zavis\ideas\yarmeal\patrol\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
claude --dangerously-skip-permissions -p "You are a one-off COVER BACKFILL session for Population: Zero (not a content patrol - do NOT write any posts, comments, likes or follows). Read patrol/PATROL.md, especially the cover rules. Task: query the remote D1 (pz-db, --remote) for all posts where og_image IS NULL, read each post's title/body/kind, and for every post that should have a cover per the rules, run 'node patrol/gen-cover.mjs --slug <short-slug> --prompt \"<scene description fitting the post>\"' (OPENAI_API_KEY is in the environment) and collect the printed CDN URLs. Hard rules: illustration covers are mood illustrations, never fake photos of real news events or real people; posts that already have media_type youtube keep their official thumbnails (skip them); vary the scenes so covers don't look repetitive; max 25 covers this run. Then write patrol/patrol-output.json containing ONLY {\"cover_updates\":[{\"post_id\":N,\"og_image\":\"url\"}...]} and run 'node patrol/apply.mjs --remote'. Verify with one D1 query that og_image counts increased, then report a summary." >> "%LOGDIR%\cover-backfill.log" 2>&1
del "C:\works\zavis\ideas\yarmeal\patrol\.patrol-lock" 2>nul
