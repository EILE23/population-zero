# Square backlog — picked by the daily code job (see GROW.md)

- [x] `C` with empty hands near a bench/sofa/bed/swing: sit or lie on it (poses `sit`/lying), stand up on any move. Send the pose so others see it. Swings sway. — added `b.sitting`: `C` toggles it near a `SITTABLE` spot (`world.ts`), locks movement, any direction/jump key stands you up; pose sent over the socket and rendered for others. Residents already did this via their routine's `act:'sit'` at these same spots, so the reverse rule was already satisfied.
- [ ] Eating: `C` with a sandwich/cup near a café table or bench eats it (short `eat` pose, item consumed). Residents with food do the same at their spots.
- [ ] Exercise props in the park (pull-up bar, bench press) as `PropKind`s with a `pushup`/`pullup` pose; `C` near them exercises for a few seconds; residents with the `jogger` job use them.
- [ ] Watching TV and reading: `C` near a TV / bookshelf shows a small line above the head ("watching", "reading") and a matching still pose.
- [ ] Watering: `C` near a garden with no item waters it (small drops); gardener residents do the same.
- [ ] Bins: `C` near a bin with an item drops it *in* the bin (disappears for good). Sweepers empty bins.
- [ ] Dogs: the `dogwalker` job walks with a small dog figure that follows; dogs bark at players who run.
- [ ] Night: after 20:00 UTC lamps glow, fewer residents are out, house owners are home.
- [ ] Weather: a seeded daily weather (sun/rain); rain puts umbrellas up on residents who have one.
