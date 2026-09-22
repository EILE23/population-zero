/**
 * 게임 엔진 — Climb·Square 가 쓰는 것을 한 문으로 모았다. 사람이 만든 게임(features/games/<slug>)은 여기서만 가져온다.
 * 그래야 졸라맨 모션·주민 직업·물리·방이 광장에서 자라면 모든 게임이 같이 자란다.
 *
 * - 졸라맨: figure(ctx, x, y, s, pose, face, color, t, arms). 자세 목록은 FigPose. 사람마다 다른 색은 figureColor(uid).
 * - 점프 물리(Climb): step(body, input, dt, platforms, t, crumbled) — 점프킹식 충전 점프, 공중 조향, 벽 튕김. poseOf(body) 로 자세.
 * - 2.5D 무대(Square): scene() — 깊이 → y·크기, 거리, 카메라, 캔버스 맞춤.
 * - 주민: MAPS·JOBS·jobOf(handle) — 광장의 지도·직업표. 게임에 주민을 세우려면 GameProps.residents 와 jobOf 를 쓴다.
 * - 방: connectRoom(slug, handlers) — 실시간 자리·사건·채팅. 구경꾼도 받는다.
 * - 씨앗: rng(seed)·hash(str) — 같은 씨앗이면 모두 같은 세계.
 */
export { figure, SEATED, type FigPose } from '@/lib/stickman';
export { rng, hash, figureColor, step, poseOf, collide, figPlats, band, around, platX, G, WALK, RUN, JUMP_V, JUMP_MIN, CHARGE, type Body, type Input as JumpInput, type Platform, type Pose } from '@/lib/tower';
export { ITEMS, FOOD, DEPTH_PX, PLAYER_SPEED, RESIDENT_SPEED, CHASE_SPEED, type ItemKey } from '@/lib/goose';
export { MAPS, MAP_BY_KEY, JOBS, jobOf, houses, SITTABLE, BREAKABLE, WATER_SPOTS, type GameMap, type Spot, type PropKind, type Job, type JobKey } from '@/lib/world';
export { connectRoom, type Room, type RoomUser, type RoomHandlers } from './room';
export { scene, type Scene } from './scene';
