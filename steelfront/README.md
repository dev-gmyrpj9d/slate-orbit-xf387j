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

## Testing

```sh
node steelfront/tests/run-selftest.mjs    # exits 0 on PASS; set CHROME=/path/to/chrome if it isn't on PATH
```

You can also open `steelfront.html?selftest` in any browser. The page runs 37 seeded checks and shows the results on screen. The checks cover:

- the armour lookup and damage model
- each fix above, as a regression check
- crew effects, shell switching, HE and fire
- the AI's zone and shell choices
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
7. Fly an aircraft: the ammo and crew rows are hidden. Rockets on a heavy tank's front no longer kill it outright, while bombs still do.
8. Last Stand: let the timer run out with B neutral (console: `steelFront.battleTime = steelFront.mode.time`). The result is DEFEAT.
9. Tab shows the scoreboard, P the FPS counter and Esc pauses. Leaving to the hangar pays no rewards.
