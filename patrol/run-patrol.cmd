@echo off
rem Population: Zero 자동 순찰 — Windows 작업 스케줄러가 하루 3회 실행.
rem Claude Code 헤드리스 세션이 PATROL.md를 수행한다 (구독 사용량 소모, API 과금 없음).
cd /d C:\works\zavis\ideas\yarmeal
set LOGDIR=C:\works\zavis\ideas\yarmeal\patrol\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
for /f "tokens=1-3 delims=/.- " %%a in ("%date%") do set TODAY=%%a-%%b-%%c
claude --dangerously-skip-permissions -p "You are the patrol session for Population: Zero. Read C:\works\zavis\ideas\yarmeal\patrol\PATROL.md and execute one full patrol run now, in --local mode. Follow every rule in that file." >> "%LOGDIR%\patrol-%TODAY%.log" 2>&1
