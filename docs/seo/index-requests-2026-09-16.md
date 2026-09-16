# 색인 요청 — 2026-09-16 (하루 10개 제한)

**하는 법**: Search Console(sc-domain:population.town) → 상단 검색창에 URL 붙여넣기 → "URL 검사" → **색인 생성 요청**. 한 개당 1분쯤 걸리고 하루 10개가 상한입니다. "URL이 Google에 등록되어 있지 않음"이라고 나와도 정상 — 요청만 누르면 됩니다.

아래는 현재 가장 긴(= 색인 가치가 있는) 글들이고, 사이트맵에 있는 정본 주소 그대로입니다.

```
https://population.town/p/418/late-frequency-ch-3-the-bearing
https://population.town/p/206/i-opened-one-nasa-caption-to-check-a-date-and-now-i-know-mor
https://population.town/p/55/the-1-in-4-unemployment-number-going-around-where-it-actuall
https://population.town/p/238/the-cert-already-told-you-it-was-garbage-it-just-took-until-
https://population.town/p/227/16-years-ago-today-an-n64-cartridge-invented-a-genre-nothing
https://population.town/p/325/anthropic-says-china-s-ai-labs-siphoned-200-million-claude-e
https://population.town/p/394/this-week-s-verge-installer-airpods-refresh-meta-s-ai-agent-
https://population.town/p/300/interchange-itemized-what-a-100-card-swipe-actually-buys
https://population.town/p/333/you-don-t-own-the-subscription-and-you-don-t-own-the-game-ei
https://population.town/p/424/nato-shot-a-drone-out-of-the-sky-over-lithuania-last-night-a
```

같이 넣어두면 좋은 것 (자리가 남으면):
```
https://population.town/
https://population.town/about
```

**왜 이걸 하나**: 지금 표본 15개 중 색인 2개, 6개는 "구글이 URL을 모름" 상태입니다. 도메인이 2주밖에 안 됐고 외부 링크가 0이라 크롤 예산이 거의 없어요. 수동 색인 요청은 그 줄을 새치기하는 유일한 수단이고, 내일 PH 런치의 백링크가 붙으면 그때부터는 자동으로 돕니다.

**다음 확인**: 9/21에 `patrol/gsc-report.json`의 index_coverage로 재측정 — 요청한 10개 중 몇 개가 "Submitted and indexed"로 바뀌었는지 봅니다.
