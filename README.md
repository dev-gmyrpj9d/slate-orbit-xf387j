# Wild Feast Islands

Source and build tooling for the Roblox place **Wild Feast Islands**.

| Path | What it is |
| --- | --- |
| `place/WildFeastIslands.original.rbxl` | The untouched uploaded place (md5 `c631449a540d771a2813b7ab8df8acef`). Never edited. |
| `src/` | Every script in the place, Rojo layout (`X.luau` ModuleScript, `X.server.luau` Script, `X.client.luau` LocalScript), mirroring the instance tree. |
| `build/WildFeastIslands.rbxl` | The playable place: the original plus `src/` plus `tools/scene.luau`. Open this in Studio. |
| `tools/` | Lune scripts: `extract`, `build`, `roundtrip` (proves no original instance was lost), `sourcemap`, `mapview` (top-down SVG of the built place), `check.sh`. |
| `tests/` | Offline Lune tests (`lune run tests/run.luau`). |

Tools are pinned in `mise.toml` (`mise install`). `tools/check.sh` runs StyLua, the tests, the build, the round-trip check and a strict `luau-lsp analyze` with Roblox definitions.

To go back to the original, open `place/WildFeastIslands.original.rbxl`. To go back to the first pass, run `git checkout a4246c5 -- src` and rebuild.

## Passes

Earlier passes found no gamepasses in the original place. There is now a small optional lineup: the Lantern Egg (always hatches a Lanternkit companion), the Painter's Kit (throw trails) and the Field Satchel (+2 food bar pins). Ownership is checked on the server, prices come from Roblox, and buying stays disabled until real pass IDs go into `Config.Passes`. Design, configuration steps and Studio checks are in [`docs/MONETIZATION.md`](docs/MONETIZATION.md).

## Third pass (this branch)

Built from the owner's eight screenshots. The per-image analysis, what was observed versus inferred, and what was deliberately *not* copied are in [`docs/SCREENSHOT_ANALYSIS.md`](docs/SCREENSHOT_ANALYSIS.md). The licensed image references are in [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md#image-references).

- **Throw meter.** A segmented gauge beside the aim point, not over it. It shows the predicted outcome in words ("Catch: Puffhop", "Lands 24 studs away") and names the actual input ("Release R2 to throw"). The goal card and hint step aside while you aim.
- **Throw feel.** The arm cocks back with power, whips over and follows through, and everyone sees it. Your own throws show a landing ring that closes in as the food falls.
- **Discovery.** A journal-plate card for each new animal or favourite: side-profile animal, silhouette first, the name written in. Arriving on an island shows a banner with your tally there.
- **World.**
  - Stepping-stone paths from the spawn to both bridges and the Feast Cove pier, signposts that point the way, and zig-zag bridge lanterns.
  - Tidier world labels.
  - Placement is checked against the built place, and `tools/mapview.luau` renders a top-down map.
- **Network.** Resting animals no longer replicate every frame. The idle bob moved to the client (see the [audit](docs/AUDIT.md#third-pass)).

## Second pass

- **Audit:** [`docs/AUDIT.md`](docs/AUDIT.md). Five defects fixed: rejoin lock race, free lure extension, decor lane stall, pin double-toggle, catch hint radius.
- **Art direction and references:** [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md). New palette and font (Builder Sans). Emoji, ALL CAPS and "!" hype removed from player-facing text. Every text colour pair is at least 4.5:1 contrast.
- **New features:**
  - Shop tab with 3D companion previews.
  - Client-drawn companions that follow their owner.
  - Trusted animals come over to greet you.
  - Two settings: *Tap to aim, tap again to throw* and *Larger interface*.

## First pass (PR #1)

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

Done offline (both passes, `tools/check.sh`):
- StyLua check.
- `luau-lsp analyze` in strict mode with Roblox definitions on all of `src/`.
- 38 Lune tests (third pass: idle-bob split and write budget, throw meter copy, throw and landing curves, discovery rules, wayfinding placement against the built place; earlier: pass rules, save schema v4, companion rig, monetization boundaries, plus the first pass's tests):
  - pose curves are finite and mirrored
  - idle choices behave as intended
  - separation pushes animals apart
  - all 106 species plus the giant build a valid joint graph whose Motor6D C0/C1 reproduce the build pose
  - marketplace code only in PassService and Shop, no paid randomness or developer products
- Round-trip check: the built place still contains every instance of the original.

Needs Roblox Studio (not run here; pass-specific checks are in `docs/MONETIZATION.md`):
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
6. New HUD on desktop, phone and gamepad:
   - Builder Sans loads.
   - The Shop and Settings tabs fit the panel.
   - Larger interface still fits a phone screen.
   - Tap to throw works with mouse, F, touch and R2.
7. At trust level 3, idle animals walk up and stop about 5 studs away.
8. Third pass:
   - **Idle bob.** Resting animals still breathe on every client. Compare network receive with the Developer Console / MicroProfiler before and after.
   - **Throw pose.** The arm wind-up and follow-through show on R15 and R6 avatars, and another player sees the swing. This needs `Motor6D.Transform` set in PreSimulation to layer over the default animations.
   - **Throw meter and ring.** The meter clears the target on a phone in landscape and portrait. The landing ring sits on the ground and vanishes on impact.
   - **Discovery.** The card's viewport frames the animal (side profile) and closes on tap. The island banner shows once per arrival.
   - **Wayfinding.** Signposts read well from the path. Lanterns look right on the bridges. Stones don't z-fight with the grass.

Ambient island audio (waves, birds) would need licensed audio from the Creator Store. It was left out rather than guessing asset IDs.
