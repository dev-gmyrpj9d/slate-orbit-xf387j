# Steel Front

A single-file WebGL2 combined-arms battle game (tanks, SPAA, aircraft, 8 vs 8 against AI). It has nothing to do with the Roblox project in the rest of this repo.

| Path | What it is |
| --- | --- |
| `steelfront.html` | The playable game. Open it in Chrome, Edge, Firefox or Safari. |
| `original/steelfront.original.html` | The uploaded baseline (`steelfront (5).html`, md5 `f54eb05bbc2964cbd361c15fc673c020`). Never edited. |
| `tests/run-selftest.mjs` | Runs the built-in self-test in headless Chrome. |

## Pass 1: War Thunder-style ground combat

**Fixes**

- A direct rocket, artillery or HE hit counted as being inside the kill radius, so it always destroyed the tank. One 25 mm-pen RS-82 on a Tiger's front plate was a kill. Now only bombs kill by distance alone. A direct strike has to beat the armour it hits, and the blast multiplier is capped at 1.
- The reload ring under the gun marker used the base reload, so it was wrong with a damaged breech and with autocannon magazines.
- The gun still aimed and fired during field repair, even though the crew is "outside fixing the tank".
- Conquest AI ignored an owned zone while enemies were capturing it, as long as no ally was inside it.
- In Last Stand, timing out with zone B neutral counted as "B held", which is a win. It is now a loss: "zone B was neutral, not held".
- The `window.steelFront.select(key)` console hook threw for every historical vehicle.

**New gameplay**

- **Shell choice (1 / 2 / 3).** Every cannon tank carries three shell types:
  - **AP:** the most penetration.
  - **APHE:** 88% of the penetration but much more damage behind the plate.
  - **HE:** bursts on contact. It can't get through real armour but wrecks open-topped vehicles.

  Switching while the gun is loaded unloads it and reloads the new shell. Switching mid-reload just changes the round being loaded. AI tanks pick HE against open tops, APHE when it clears the target's front armour, and AP otherwise.
- **Crew and modules.** Ground vehicles have 3 to 5 crew seats: commander, gunner, loader, driver, radio operator.
  - A penetration's spall knocks out crew depending on where it lands (turret, hull front, side, roof or rear).
  - With no gunner the gun can't traverse or fire. With no driver the tank can't move. With no loader reloads take 60% longer (a 3-man crew's gunner loads).
  - A spare crewman takes over the gunner's or driver's seat after 5 s.
  - The vehicle is lost when fewer than two crew remain.
  - The HUD shows crew status, and a hit on you lists what it broke.
- **Engine fires.** Penetrations into the engine bay can start a fire, which drains hull integrity. Press **F** to put it out; AI crews put theirs out after a few seconds.
- **Penetration indicator.** Over an enemy vehicle, the gun marker turns green (likely penetration), yellow (maybe), red (no) or grey (likely ricochet) for the loaded shell. In the gunner sight it also shows penetration against effective armour in mm. It only appears when you are already aiming at the vehicle, so it doesn't reveal positions.

## Pass 2: finding enemies, easier enemy AI

This pass answers playtest feedback: it was hard to tell where the enemy was, and the enemy was too strong.

**Enemy location cues**

- **Spotting:** an enemy counts as spotted while you or an ally can see it, for 4 s after its main gun fires within 900 m of your side, and for 6 s after it hits you. You see an enemy if it is in line of sight and either within 650 m or in your view out to 1,200 m (1,800 m for aircraft). Before this pass only the AI and aircraft spotted anything, and only on the minimap.
- **Markers:** a spotted enemy gets a red marker over it with its range in metres. When it is off-screen, a red arrow at the screen edge points to it (up to 8, nearest first). It also still shows on the minimap.
- **Hit direction:** a red arc around the crosshair points to whoever just hit you, for 3 s.
- **M** turns the markers and arrows on or off. The setting is saved; the hit arc always shows.

**Enemy AI handicap.** All the numbers are in the `ENEMY_AI` table. Only team 1 AI is affected; allies, the player and the damage model are unchanged.

| | Before | Now |
| --- | --- | --- |
| Range at which enemies spot targets | 520 m (flak 1,300 m) | ×0.85 |
| Delay before the first shot at a new target | 0.8–2.0 s | ×1.8 |
| Aim error (tanks, flak) | — | ×1.7 |
| Pause after each shot | 0.2–1.0 s | 0.9–2.2 s |
| Enemy pilots' aim error | — | ×1.5 |
| Shell against armour | APHE or AP | AP (less spall) |

Over 3 × 180 s simulated Conquest battles, the enemy used to out-kill your side 27 to 17. With the handicap your side leads 26 to 18.

## Pass 3: easier flying, adjustable speed

This pass answers playtest feedback: the plane was too hard to control, and there was no easy way to set its speed.

**Speed.** Hold **W / S** to open or close the throttle, or press **1 / 2 / 3 / 4** for 25 / 50 / 75 / 100%. A throttle bar sits left of the crosshair:

- the green fill is the throttle setting
- the white tick is your current speed
- the blue tick and the `→` number are the speed (km/h) you'll settle at in level flight
- the red tick is the stall speed

The left panel also shows the presets (the current one highlighted) and `THR n%→km/h`. The 1–3 keys still pick shells in a tank.

Pass 3 also added an "easy flight" assist. It was removed in Pass 5 (see below).

## Pass 4: lock-on rockets

**Lock-on rockets (arcade, game-only).** Two new player vehicles carry SF-G rockets that steer themselves:

- **Hornet R-5** (Ground forces, Steel Front): a light rocket tank with a 50 mm gun and two turret pods of 4 rockets. The pods reload one rocket every 8 s.
- **P-51D Kestrel** (Aircraft, Steel Front): a Mustang-airframe variant with six .50 cal guns and 6 lock-on rockets instead of bombs. T rearms them as usual.

How it works:

1. A dashed seeker circle sits round the crosshair. Keep an enemy tank or aircraft inside it, in range (1,000 m for tanks, 1,400 m for aircraft) and in clear view. The seeker picks the enemy nearest the crosshair by itself.
2. A yellow box closes in on the target (`LOCKING n%`). After 0.6 s it turns into a red `LOCKED TANK/AIR · range` box with `R: FIRE`.
3. Press **R**. The rocket steers to the target, leading it, and flies a shallow loft against tanks so it clears crests. It bursts next to aircraft (proximity fuse), and has to beat the armour it hits on tanks (150 mm penetration). Without a lock, R fires the rocket straight ahead.

Friendly units, wrecks, targets out of range and targets behind terrain or smoke never lock. AI units never use these vehicles, and an AI launcher could not home, so enemy difficulty is unchanged.

## Pass 5: no flight assists

Playtest feedback asked for all of easy flight to go, so it has been removed as a feature, not just switched off:

- **Gone:** the auto pull-up (removed first, in Pass 4), stall protection, the automatic extra throttle, the 40° climb/dive cap and the steering smoothing. The L key, the easy-flight chip and the `EASY` / `+AUTO` labels on the HUD are gone too.
- **Same model as the AI:** the player's plane now flies exactly the same model as AI pilots. Fly slow or pull too hard and you stall; hold a dive and you hit the ground.
- **Old saved setting:** the `steelfront.easyflight` value an earlier build saved is deleted on load, so it can't turn anything back on.
- **Kept:**
  - mouse-aim, A/D roll and C free look
  - the W/S throttle and the 1–4 presets
  - the throttle bar with its cruise and stall ticks
  - the STALL, PULL UP and RETURN TO THE BATTLE AREA warnings, which only warn
  - the battle-area boundary: past the map edge or above 2,600 m the plane still turns back, as in the original game
  - the lock-on rockets

## Testing

```sh
node steelfront/tests/run-selftest.mjs    # exits 0 on PASS; set CHROME=/path/to/chrome if it isn't on PATH
```

You can also open `steelfront.html?selftest` in any browser. The page runs 84 seeded checks and shows the results on screen. The checks cover:

- the armour lookup and damage model
- each fix above, as a regression check
- crew effects, shell switching, HE and fire
- the AI's zone and shell choices
- spotting, the marker and arrow directions, and the enemy AI handicap
- unassisted flight: no assist code or saved setting is left. A straight-down aim dives steeply into the ground, an idle-throttle climb stalls and the throttle stays put. The player's input path matches the raw flight model exactly. Also checked: the throttle keys, level-flight speed per throttle, and that L does nothing
- lock-on rockets: which units can lock (friendly, out of range, outside the circle, destroyed), lock timing, tank→tank (moving), tank→aircraft, plane→aircraft and plane→tank hits, unguided fire without a lock, AI never homing, pod reload, the R key and the lock HUD
- two 150 s simulated battles (Conquest and Last Stand) checked for exceptions, NaNs and zombie crews

The self-test uses a throwaway profile and never writes your save. `?nointro` skips the intro.

## Manual QA checklist

Run this in a real browser after changes to gameplay, HUD or input.

1. Launch: the intro plays, and Esc skips it to the hangar. Every vehicle card selects, and the hangar info panel lists **Shells** for cannon tanks but not for the Wirbelwind or aircraft.
2. Deploy in a Sherman (Conquest). Click to lock the mouse. W/A/S/D drive the tank, the mouse aims and left click fires. Shift or right mouse toggles the gunner sight; the wheel zooms.
3. Press 1, 2 and 3. Each press shows "LOADING …" and the selected button is highlighted. With a loaded gun, switching starts a reload. Fired shells hit with visibly different results (HE gives a small burst on the ground).
4. Aim at an enemy: the marker turns green, yellow, red or grey. In the sight it shows `pen/effective mm`. A Panther's front hull is red for the Sherman and its side is green.
5. Get penetrated, or use the console. Crew chips cross out, the hit message lists the knocked-out crew, and "New gunner in Ns" appears and resolves.
6. Catch fire: "ON FIRE — F to extinguish" appears. F puts the fire out without starting a repair. A second F starts the repair. During the repair the gun neither turns nor fires.
7. Fly an aircraft: the panel shows throttle presets 1–4, not shells or crew. W/S and 1–4 change the throttle bar and the speed settles at the blue tick. There are no assists: at 0% throttle in a climb the plane stalls (STALL warning, throttle stays at 0%), and aiming straight down dives into the ground. Rockets on a heavy tank's front no longer kill it outright, while bombs still do.
8. Last Stand: let the timer run out with B neutral (console: `steelFront.battleTime = steelFront.mode.time`). The result is DEFEAT.
9. Spotted enemies show a red marker with their range. Turn away and an edge arrow points back at them; M toggles both. Get hit and a red arc points to the shooter.
10. Deploy the Hornet R-5, then the P-51D Kestrel. Hold an enemy inside the dashed circle: the yellow box turns red (LOCKED), R fires, and the rocket curves onto the target. A friendly unit never locks.
11. Tab shows the scoreboard, P the FPS counter and Esc pauses. Leaving to the hangar pays no rewards.
