# Wild Feast Islands

Source and build tooling for the Roblox place **Wild Feast Islands**.

| Path | What it is |
| --- | --- |
| `place/WildFeastIslands.original.rbxl` | The untouched uploaded place (md5 `c631449a540d771a2813b7ab8df8acef`). Never edited. |
| `src/` | Every script in the place, Rojo layout (`X.luau` ModuleScript, `X.server.luau` Script, `X.client.luau` LocalScript), mirroring the instance tree. |
| `build/WildFeastIslands.rbxl` | The playable place: the original plus `src/` plus `tools/scene.luau`. Open this in Studio. |
| `tools/` | Lune scripts: `extract`, `build`, `roundtrip` (proves no original instance was lost), `sourcemap`, `check.sh`. |
| `tests/` | Offline Lune tests (`lune run tests/run.luau`). |

Tools are pinned in `mise.toml` (`mise install`). `tools/check.sh` runs StyLua, the tests, the build, the round-trip check and a strict `luau-lsp analyze` with Roblox definitions.

To go back to the original, open `place/WildFeastIslands.original.rbxl`, or run `git checkout 611111d -- src` and rebuild.

## Gamepasses

I searched every script in the place for `MarketplaceService`, `UserOwnsGamePass`, `PromptGamePassPurchase`, `PromptProductPurchase`, `ProcessReceipt` and any gamepass, VIP or premium checks. None exist. The only purchases spend in-game coins and research, so all features are already free to every player and no code needed changing. `tests/monetization.spec.luau` fails if a gamepass gate or purchase prompt is ever added. Marketplace settings on roblox.com were not touched. Any gamepasses listed on the game page don't grant anything in game.

## Improvements in this pass

Benchmark: the public listing for *Throw Food For Animals* (Roblox search API) describes this loop: throw food far, attract and collect animals, earn, buy better food, train throw power, open new areas. Wild Feast Islands already has an equivalent loop. What it lacked was the animals *feeling alive*, so that's where this pass goes. No assets or code were copied.

- **Animal animation.** `AnimalFactory` joins heads, legs, ears, tails, wings and claws to the body with Motor6D joints. The rules are in `Shared/AnimalMotion`. The client-side `AnimalAnimator` poses them every frame:
  - a diagonal walk gait, hops for hoppers and frogs, rippling crab legs
  - ear twitches, tail wags when happy, wing flaps, claw snaps
  - heads that turn toward you, eye blinks
  - fin and tail sway on the feast giant

  Nothing here affects gameplay. The server still moves one root per animal, and the mouth and catch positions are unchanged.
- **Animal behaviour.** Idle animals now choose to wander, sniff the grass, stop and watch a nearby player, or lie down to rest (hovering moths never rest). Animals on the same island push apart instead of overlapping. The pose is published as a `Pose` attribute.
- **SFX.** There are distinct cues for throw, eat, refuse, splash, ground thud, reward, perfect catch, fanfare (trust level-up, favourite found, feast finished) and a bell chime (feast ready or giant surfacing). Each cue gets slight random pitch. The original defined a splash sound but never played it. Other players' impact sounds now only play within 80 studs of your camera, instead of across the whole server.
- **VFX.** Thrown food leaves a short trail, a perfect catch shows an expanding ring, happy animals pop hearts and refusals give a small puff. All of these respect the Reduced effects setting and the existing effect cap.
- **Scene.** The grade is warm mid-afternoon light with slightly richer colour, a soft bloom that only catches the glowing props, and faint sun rays (`World/Ambience`, applied at runtime). Lighting uses ShadowMap, which is set in the file because scripts can't change it.

## Validation

Done offline:
- StyLua check.
- `luau-lsp analyze` in strict mode with Roblox definitions on all of `src/`.
- 13 Lune tests:
  - pose curves are finite and mirrored
  - idle choices behave as intended
  - separation pushes animals apart
  - all 106 species plus the giant build a valid joint graph whose Motor6D C0/C1 reproduce the build pose
  - no monetization hooks exist
- Round-trip check: the built place still contains every instance of the original.

Needs Roblox Studio (not run here):
1. Play Solo and a 2-player local server.
   - Animals animate, blink and turn their heads on every client.
   - Idle animals sniff, rest and watch.
   - Animals no longer overlap.
2. Perfect, good, ground and refused throws all play their sounds and effects.
   - Hearts and the ring appear.
   - Reduced effects turns them off.
3. `rbxasset://sounds/swoosh.wav`, `clickfast.wav` and `victory.wav` load on desktop and mobile. The other cues reuse files the original already used. A missing file is skipped silently.
4. Feast: the chime plays when the feast is ready, the fanfare plays when the giant leaves, and the giant's fins sway.
5. The lighting grade and ShadowMap look right, and there's no frame-time regression on a low-end phone.

Ambient island audio (waves, birds) would need licensed audio from the Creator Store. It was left out rather than guessing asset IDs.
