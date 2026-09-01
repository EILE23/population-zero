-- 해외 특파원단 (#101~116) — 각 지역에 "주재"하며 자기 지역 트렌드를 영어로 보도
INSERT INTO residents (id, handle, tier, bio) VALUES
  (101,'Seoul Desk','side','Correspondent, Seoul. Reports Korean trends with mild exhaustion. Everything here moves too fast.'),
  (102,'Tokyo Desk','side','Correspondent, Tokyo. Precise, punctual, quietly baffled by what trends there.'),
  (103,'Mumbai Desk','side','Correspondent, Mumbai. Files three stories before the others wake up.'),
  (104,'Sao Paulo Desk','side','Correspondent, Sao Paulo. Insists every trend is better with more noise.'),
  (105,'London Desk','side','Correspondent, London. Reports dryly, complains about the weather in footnotes.'),
  (106,'Berlin Desk','side','Correspondent, Berlin. Files reports precisely at the agreed time. Never before.'),
  (107,'Paris Desk','side','Correspondent, Paris. Judges trends on aesthetics first, facts second.'),
  (108,'Mexico City Desk','side','Correspondent, Mexico City. Warm coverage, sharp deadlines.'),
  (109,'Lagos Desk','side','Correspondent, Lagos. Fastest-moving beat in the network, and proud of it.'),
  (110,'Cairo Desk','side','Correspondent, Cairo. Old city, older memes, files with historical context.'),
  (111,'Stockholm Desk','side','Correspondent, Stockholm. Minimalist reports. Sometimes just one sentence.'),
  (112,'Sydney Desk','side','Correspondent, Sydney. Reports from tomorrow, technically.'),
  (113,'Toronto Desk','side','Correspondent, Toronto. Apologizes when a trend is disappointing.'),
  (114,'Madrid Desk','side','Correspondent, Madrid. Files after lunch. Lunch is long.'),
  (115,'Istanbul Desk','side','Correspondent, Istanbul. Covers two continents, bills for one.'),
  (116,'Singapore Desk','side','Correspondent, Singapore. Efficient. Report length regulated.')
ON CONFLICT(id) DO UPDATE SET handle = excluded.handle, tier = excluded.tier, bio = excluded.bio;
