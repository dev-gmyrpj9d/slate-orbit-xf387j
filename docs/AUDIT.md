# Audit (second pass)

The baseline is PR #1's `src/` and `build/WildFeastIslands.rbxl`. The untouched upload is still `place/WildFeastIslands.original.rbxl` (md5 `c631449a540d771a2813b7ab8df8acef`). Every finding below comes from reading the code. Nothing here was observed in Studio.

## What the game is

- **Core loop.** A hold-to-charge throw sends food along a shared arc (`Shared/Trajectory`). The server simulates the projectile (`FeedingService`) and decides how it lands: in the mouth, near the animal, or on the ground. Coins, research and trust go into a profile that is sanitised and session-locked (`DataService`, `SaveSchema`).
- **Content.** Built from data in `Shared/Content`: 106 species (6 residents plus 100 visitors), 156 foods, 200 recipes, 300 quests, 150 decorations and 105 upgrades, across three islands. There is also a co-op feast event, the Grand Mumbleback in Feast Cove (`FeastService`).
- **Remote security.** Clients send intents only. `Validation.parseAction`/`parseThrow` check shape, type, length and finiteness. Requests are rate limited, and repeatable purchases carry an `expect` value so a double tap can't buy twice.

## Defects found and fixed

| Severity | Where | Problem | Fix |
| --- | --- | --- | --- |
| Medium | `DataService` `onPlayerAdded` | A rejoin during a slow load started a second load of the same key on the same server. When the first load ended, it released a lock the live session depended on. The next autosave saw a "lost" lock, and the session stopped saving. | Track in-flight loads per key (`loading`). A rejoin now waits for both a running load and a final save. |
| Medium | `AnimalService.summon` | Using a lure on a visitor that was already present extended its stay without spending the lure, so one lure could hold a visitor forever. | No extension when no lure is spent. The message now says the lure is kept. |
| Low-Med | `DecorService.sync` | A waiting player who removed every decoration stayed in the wait list and was later handed a lane they couldn't use. A lane holder with an empty garden kept their lane. | An empty garden releases its lane and leaves the queue. |
| Low | `ActionService` `PinFood` | The pin toggle had no duplicate protection, so a double tap pinned and then unpinned. | The client sends `expect` (pinned or not), and stale toggles are dropped. |
| Low | `ThrowController` | The client's "Catch" hint ignored the Mouth Reading upgrade bonus and the food radius. Throws the server would count as clean catches showed no hint. | The client now runs the same radius test as the server. |

## Noted, not changed

- **Idle bob replication.** *Fixed in the third pass, see below.*
- **Unused fields.** `tutorialStep` (saved), `Config.Throw.BaseMaxSpeed`, `BaseCooldown`, `PreviewBaseSeconds` and `Config.Kitchen.MaxCookPerRequest` are never read. The tutorial is driven by the next-goal progression, which is already saved through normal progress. They were kept for save compatibility.
- **Environment.** The world is baked into the place file (`WorldBuilder` only runs when it is missing). This pass didn't move or add world props. *The third pass adds them with structured offline checks instead (see below).*

## Gaps closed in this pass

- **Accessibility.** Throwing needed a held button. The Game Accessibility Guidelines say to "avoid / provide alternatives to requiring buttons to be held down" and to "allow interfaces to be resized". This pass adds two settings: **Tap to aim, tap again to throw** and **Larger interface** (a 1.2× HUD scale).
- **Trust you can see.** Trust only showed as a number. Animals at trust level 3 or above now trot over to greet that player (`AnimalMotion.pickIdle` "greet" mode, `AnimalService.nearestFriend`).
- **UI tone.** The UI used emoji icons, ALL-CAPS banners, "!" on almost every message, and white text on light-orange buttons with low contrast. All of it was replaced (see `ART_DIRECTION.md`).
- **Monetization.** The game had no gamepasses at all (PR #1 audit). There is now a small optional lineup (see `MONETIZATION.md`).

## Third pass

The starting point was the owner's eight screenshots ([SCREENSHOT_ANALYSIS.md](SCREENSHOT_ANALYSIS.md)) and the open item above.

- **Idle bob replication (fixed).**
  - **Before:** `AnimalService.move` wrote every animal's root CFrame every Heartbeat, so all of up to 26 animals replicated at 60 Hz even while resting.
  - **After:** the body motion is split in `Shared/AnimalMotion`:
    - `bodyMotion` covers what gameplay or other players must see: walk gaits, the anticipation hop, the happy spin, the refusal shake. It stays on the server.
    - `idleBob` covers the breathing, sniffing and chewing bob. Each client adds it locally in `AnimalAnimator`.
  - The server now writes only when the pose changes by more than `WriteEpsilon` (0.002 studs or radians), and `AnimalService.stats.writes` counts the writes.
  - **Tests:**
    - The split reproduces the old bob exactly for every state, pose and archetype.
    - A simulated resting or idle animal makes at most a handful of writes in 10 s while settling, then none.
    - A walking animal still writes every frame.
  - **Still needs Studio:** the real bandwidth saving.
- **Catch hint vs. mouth position.** The server's mouth position no longer includes the old 0.04–0.08 stud idle bob. The difference is below the catch radius margin, so clean catches are unaffected.
- **Throw readability.**
  - The single horizontal power bar is now a segmented meter beside the aim point. It shows the predicted outcome in words and the real input to press (`ThrowReadout`, `ThrowMeter`).
  - Your throws show a landing ring that closes in as the food falls (`Effects`, `Feel.landingRing`).
  - Throws have a wind-up and a follow-through on the character (`ThrowPose`, `Feel`).
- **Discovery.** Spotting an animal or finding a favourite now gets a journal-plate card (`Discovery`, `JournalReveal`), and arriving on an island shows a short banner with your tally there. The favourite toast was folded into the card.
- **World.**
  - `World/Wayfinding` adds stepping-stone paths, signposts and bridge lanterns at server start, and tidies the baked world labels.
  - Offline checks run against the built place (`tests/wayfinding.spec.luau`), and the pass skips any stone that would land on a prop.
  - `tools/mapview.luau` renders a top-down map for review.
- **Gate label copy.** Gate labels used ALL CAPS ("LOCKED: …"). They now read "Locked: … from the Map tab".

## Fourth pass

- **Silent sound cues (fixed).**
  - **Problem:** `swoosh.wav`, `electronicpingshort.wav`, `clickfast.wav` and `victory.wav` are not in the current client's file manifest. The manifest is `rbxManifest.txt` in MaximumADHD/Roblox-Client-Tracker, client 0.747.0.7471481, and it lists exactly 11 files under `content/sounds`. So the throw, reward, perfect-catch, click, chime and fanfare cues were most likely silent.
  - **Fix:** every cue now uses a shipped file, listed in `Shared/EngineSounds`.
    - The throw uses `action_jump.mp3`.
    - The reward, perfect-catch, chime and fanfare cues are short pitched note sequences, built from the `volume_slider.ogg` tick at just intervals. There is one Sound per note, so overlapping notes keep their pitch.
  - **Test:** `tests/sound.spec.luau` fails on any `rbxasset://sounds/` path that isn't shipped, and on any uploaded asset ID.
- **Shore ambience.** `Client/Controllers/ShoreAmbience` plays one looping engine sound (`action_swim.mp3`, slowed and quiet). Its volume follows the camera's distance to the nearest shoreline, so beaches and bridges hear the sea and the island centres stay quiet. It is off when Sound is off. No Creator Store audio was used: none can be licence-checked or ID-verified from here.
- **Animal silhouettes.** These follow the reference principles in [ART_DIRECTION.md](ART_DIRECTION.md#image-references):
  - Hoppers have dark ear tips (from the hare photo) and a pale belly.
  - Foxes have dark ear tips and a pale chest.
  - Boars have a dark back ridge and a paler underside.
  - Ear tips hang from the ear (`AnimalMotion.PARTS.EarTip`), so they move with it. Every detail part is welded, not animated, so the joint count is unchanged.
  - `tools/profileview.luau` renders side profiles of any species, from the current factory or an older copy, for review.
- **Anticipation.** While anticipating, animals turn their heads toward the food flying at them (`Effects.nearestFood`) instead of the player.

## Fifth pass

`tests/silhouette.spec.luau` checks every one of the 106 species: each feature and detail part touches the model and isn't hidden inside another part. Details that belong to a moving part must ride on it. The largest model must stay within 64 parts.

**Defects it found, now fixed:**
- **Floating or buried visitor features (18 parts, 11 visitors).** Features sat at fixed coordinates whatever the body plan. Whiskers floated off hopper and frog faces, moth spots, glow orbs and crab horns hung in the air, and snail and tortoise spots and snail fluff were buried in the shell. Features are now placed from the head and back each body plan actually builds (`anchorFor`).
  - Moth spots became eye-spots that flap with the wing.
  - The glow became a lure bead on a swaying stalk.
- **Fox tails (all 10 fox species).** The tail drooped at +25 degrees while its glowing tip sat where a raised tail would end, so the tip floated. The brush is now raised to meet its tip.
- **Snail spiral (all snails).** It was a small ball entirely inside the shell, so it was never visible. It is now a pale centre and a dark band, as side discs that break the shell's surface.

**New details per family** (reference principles: one or two strong add-ons per species, two-tone bodies):
- bird: dark wing tips that flap with the wing, and a tail fan that wags
- tortoise: a ring of shell scutes
- otter: a dark tail rudder
- crab: dark pincer tips that snap with the claw
- frog: a pale throat and a dark back stripe
- moth: a pale collar and default antennae (not doubled for antenna or lure visitors)

All of these are welded, or ride on an existing joint, so the joint count is unchanged.

**Personality motion** (`AnimalMotion`):
- birds peck in quick jabs when sniffing
- tortoises look around slowly
- watching crabs raise and wave their claws
- moths hover-bob while idle (client-side, so no network cost)

The new motion has its own tests. The regression test keeps the old bob exact for every other case.

**Sound lifecycle:**
- A tune that is already playing can't restart within 0.25 s, so a burst of rewards doesn't stack into noise.
- Queued notes re-check the Sound setting before playing.
- The shore loop can only start once.
