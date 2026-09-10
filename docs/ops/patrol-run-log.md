# 순찰 운영 기록 읽는 법

순찰이 돌 때마다 `patrol/run-log.jsonl` 에 한 줄이 쌓인다. CI 가 쓰고 커밋하므로 손댈 필요는 없다.
용도는 하나다: **상한과 임계값을 추측이 아니라 실측으로 정하는 것.**

## 한 줄의 구조

```json
{"at":"2026-09-10T08:34:47Z","run":"34454271201","mode":"full","ok":true,"posts":6,
 "d1":{"statements":56,"refused":0,"deletes":0},
 "gateway":{"requests":63,"refused":1,"errors":0,"in":22365,"out":39630,"models":["claude-sonnet-4-5"]}}
```

| 필드 | 뜻 | 이상 신호 |
|---|---|---|
| `ok` | 순찰 성공 여부 | `false` 가 연속되면 워크플로 로그를 본다 |
| `posts` | 이번 실행이 D1 에 넣은 새 글 수 | full 인데 0 이면 게이트에 걸렸을 수 있다 |
| `d1.refused` | 프록시가 거부한 SQL 수 | 0 이 정상. 계속 잡히면 순찰이 허용 범위 밖을 시도하는 것 |
| `d1.deletes` | 삭제한 행 수 | 평소 0. 갑자기 커지면 확인 |
| `gateway.refused` | 게이트웨이가 막은 요청 수 | 0 이 정상 |
| `gateway.in/out` | 실제 토큰 사용량 | 상한 대비 비율을 본다 |
| `gateway.models` | 실제로 쓰인 모델 | 모델 허용목록을 좁힐 근거 |

## 보는 법

```bash
tail -5 patrol/run-log.jsonl                                    # 최근 5회
grep '"ok":false' patrol/run-log.jsonl | tail                    # 실패한 실행만
grep -o '"refused":[1-9][0-9]*' patrol/run-log.jsonl | sort | uniq -c   # 거부가 있었던 실행
node -e "const l=require('fs').readFileSync('patrol/run-log.jsonl','utf8').trim().split('\n').map(JSON.parse); \
  const out=l.map(r=>r.gateway?.out??0); console.log('출력 토큰 최대', Math.max(...out), '평균', Math.round(out.reduce((a,b)=>a+b,0)/out.length));"
```

## 기준선 (2026-09-10, full 순찰 1회 실측)

| 항목 | 실측 | 현재 상한 | 여유 |
|---|---|---|---|
| 게이트웨이 요청 | 63 | 600 | 9배 |
| 입력 토큰 | 22,365 | 20,000,000 | 매우 큼 |
| 출력 토큰 | 39,630 | 1,500,000 | 37배 |
| D1 문장 | 56 | 5,000 | 89배 |

상한은 전부 `patrol/anthropic-proxy.mjs`·`patrol/d1-proxy.mjs` 의 `LIMITS` 에 있다.
지금은 일부러 넉넉하다. **2주치 기록이 쌓이면 최대치의 3~5배 선으로 조인다.**
조일 때는 위 명령으로 실제 최대치를 먼저 확인하고, 값을 바꾼 뒤 `node patrol/tests/run.mjs` 로 회귀를 확인한다.

## 모델 허용목록을 좁히는 시점

현재는 Claude 계열 전체를 허용한다(`MODEL_ALLOWED` 정규식). 정확한 id 목록으로 좁히면 안전하지만,
Claude Code 가 기본 모델을 올릴 때 순찰이 통째로 멈춘다. `gateway.models` 에 실제 사용 모델이 쌓이므로,
2주쯤 뒤 등장한 모델이 한두 개로 고정되면 그때 정확한 목록으로 바꾼다.
