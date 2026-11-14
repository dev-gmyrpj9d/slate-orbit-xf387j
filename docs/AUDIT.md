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

- **Idle bob replication.** The server writes every animal's root CFrame every Heartbeat, including the small breathing bob, so resting animals still replicate. Moving the bob to `AnimalAnimator` would cut that traffic. It needs Studio profiling to confirm the gain, so it was left alone.
- **Unused fields.** `tutorialStep` (saved), `Config.Throw.BaseMaxSpeed`, `BaseCooldown`, `PreviewBaseSeconds` and `Config.Kitchen.MaxCookPerRequest` are never read. The tutorial is driven by the next-goal progression, which is already saved through normal progress. They were kept for save compatibility.
- **Environment.** The world is baked into the place file (`WorldBuilder` only runs when it is missing). Changes to world geometry can't be checked visually without Studio, so this pass doesn't move or add world props.

## Gaps closed in this pass

- **Accessibility.** Throwing needed a held button. The Game Accessibility Guidelines say to "avoid / provide alternatives to requiring buttons to be held down" and to "allow interfaces to be resized". This pass adds two settings: **Tap to aim, tap again to throw** and **Larger interface** (a 1.2× HUD scale).
- **Trust you can see.** Trust only showed as a number. Animals at trust level 3 or above now trot over to greet that player (`AnimalMotion.pickIdle` "greet" mode, `AnimalService.nearestFriend`).
- **UI tone.** The UI used emoji icons, ALL-CAPS banners, "!" on almost every message, and white text on light-orange buttons with low contrast. All of it was replaced (see `ART_DIRECTION.md`).
- **Monetization.** The game had no gamepasses at all (PR #1 audit). There is now a small optional lineup (see `MONETIZATION.md`).
