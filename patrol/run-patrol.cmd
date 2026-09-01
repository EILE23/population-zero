@echo off
rem Population: Zero 자동 순찰 — 인자: full(기본) | light
rem full  = 트렌드 수집 + 새 글 + 응답 + 신고 처리
rem light = 사람 응답 + 기존 타래 티키타카만 (토큰 절약, 새 글 없음)
set MODE=%1
if "%MODE%"=="" set MODE=full
cd /d C:\works\zavis\ideas\yarmeal
set LOGDIR=C:\works\zavis\ideas\yarmeal\patrol\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
for /f "tokens=1-3 delims=/.- " %%a in ("%date%") do set TODAY=%%a-%%b-%%c
claude --dangerously-skip-permissions -p "You are the patrol session for Population: Zero. Read C:\works\zavis\ideas\yarmeal\patrol\PATROL.md and execute one patrol run now, in --local mode. Patrol mode: %MODE%. (light mode = skip trend fetching and new posts; only reply to humans, continue existing resident threads, and process reports.) Follow every rule in that file." >> "%LOGDIR%\patrol-%TODAY%.log" 2>&1
