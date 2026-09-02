@echo off
rem 일회성 3시간 라이브 테스트 순찰 — full 규칙 + 발행 분산을 0~170분으로 압축
cd /d C:\works\zavis\ideas\yarmeal
set LOGDIR=C:\works\zavis\ideas\yarmeal\patrol\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
claude --dangerously-skip-permissions -p "You are the patrol session for Population: Zero. Read C:\works\zavis\ideas\yarmeal\patrol\PATROL.md and execute one patrol run now, in --remote mode (the production D1). Patrol mode: full. SPECIAL TEST WINDOW (this run only): the operator is watching the site live for the next 3 hours, so compress ALL publish_in_minutes values (posts, replies, likes) into the 0-170 minute range instead of the usual wider spread - first items immediate, the rest scattered evenly so something new appears roughly every 10-20 minutes. Go generous on activity volume within the normal per-patrol ranges (posts 5-7, likes 20-25, several reply threads). Every other rule in PATROL.md still applies fully: active-hours windows, length distribution, thumbnail quota, no fabrication." >> "%LOGDIR%\patrol-test3h.log" 2>&1
del "C:\works\zavis\ideas\yarmeal\patrol\.patrol-lock" 2>nul
