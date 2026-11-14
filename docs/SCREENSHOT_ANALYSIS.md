# Screenshot analysis (third pass)

The owner supplied eight still frames of another Roblox throw-food game and authorised them as analysis references. This page records what each frame shows, what a still frame can't show, and which principles were turned into original Wild Feast Islands work. The related YouTube video was not opened or researched.

**How to read this page**
- **Observed** means visible in the frame.
- **Inferred** means a reasonable reading that the frame can't prove.
- **Can't tell** covers anything that needs motion, audio or the game's code.
- Static frames can't establish sound, animation quality, timing, frame rate or the systems underneath. Those were judged from our own source, and the [audit](AUDIT.md) lists what still needs Studio.

**Capture artifacts, not game UI.** These were ignored throughout:
- the browser and YouTube controls, progress bar and video title
- "To exit full screen, press Esc"
- the black letterbox bars
- "Chrome is being controlled by automated test software"
- the mouse cursor

The Roblox top-bar buttons (menu, chat, voice) are engine UI. They do mark the top-left safe area, though.

**Not copied.** None of these were taken:
- the neon green, studded checker ground or the brown "dirt-cliff" corridor walls
- the gold-variant badger, the "$/s" income rates or "LUCK" multipliers
- the spelling reveal, the training station
- the exact HUD layout, icons or fonts

What follows are principles. Every implementation listed was written for this game in its own art direction ([ART_DIRECTION.md](ART_DIRECTION.md)).

---

## 1. Throw meter ("TAP TO THROW!")

**Composition and hierarchy**
- Observed: a third-person camera sits behind and above the avatar in a narrow canyon corridor. The vanishing point is at screen centre.
- Observed: a tall vertical gauge, about 450 px on a 768 px frame, sits *at* screen centre, directly over the path ahead. A white bar marker sits about 40% up, with a "+6" readout beside it.
- Observed: a large "TAP TO THROW!" instruction sits under the gauge, and a strength value ("18" with an arm icon) sits bottom-left.

**Typography**
- Observed: a heavy rounded display face with a dark outline and drop shadow, in all caps with an exclamation mark.
- Observed: the outline keeps it readable over both the bright grass and the dark wall.

**Colour and contrast**
- Observed: the gauge fill is a red→yellow→green vertical ramp, split into about 6 segments by dark separators.
- Inferred: colour is doing most of the work ("green = good"). The segments and the marker help, but a colour-blind player loses the "good zone" meaning.

**Anchors and safe area**
- Observed: the gauge has no anchor beyond "the middle". The strength readout is bottom-left, clear of the top-left Roblox buttons.

**Feedback**
- Observed: the gauge is impossible to miss and the next action is spelled out.
- Observed: it covers the exact part of the view the player is aiming at.

**Can't tell:** whether the marker oscillates, how "+6" is computed, whether there is a timing sweet spot, input latency, and any audio.

**What we did**
- **Placement.** `Client/Controllers/ThrowMeter` puts a vertical segmented gauge *right of* the aim point (anchored at screen-centre +70 px). The target, the arc preview and the "Catch" hint stay visible.
- **No colour coding.** `Shared/ThrowReadout` spells every state out as segment count, notch, percentage, a predicted outcome and the actual input:
  - outcomes: "Catch: Puffhop", "Lands 24 studs away", "Landing out of view"
  - inputs: "Release R2 to throw", "Tap again to throw", "B cancels"
  - a predicted catch also gets a heavier clay outline: a shape cue, not just a colour
- **Plain copy.** Sentence case, no "!". A test enforces this.
- **Cooldown.** The cooldown refills the same gauge ("Ready in 0.6s"), instead of a second bar.
- **Focus mode.** While aiming, the goal card and tutorial hint step aside (`Hud`), so the centre column stays clear.

## 2. Gold badger reveal ("GOLD / BADGER / NEW! / $18/s / tap to continue")

**Composition**
- Observed: the camera is low and close. One animal sits in the right-middle third, three-quarter view, with the food that attracted it (a banana) in the left foreground.
- Observed: nothing else is in the middle ground, so the subject reads instantly.

**Hierarchy**
- Observed, top to bottom at bottom-centre:
  - a small modifier word ("GOLD")
  - a large name ("BADGER")
  - a tilted "NEW!" sticker to the right
  - the income rate ("$18/s")
  - a small "tap to continue"
- Observed: name, then status, then value, then dismissal. That is a clear order.

**Typography**
- Observed: a heavy outlined display face, with the name in green on a green field. It is saved only by the thick dark outline.

**Colour**
- Observed: the animal is fully gold with a yellow glow, against a saturated green ground.
- Inferred: the rarity is carried almost entirely by colour and glow.

**Silhouette and model language**
- Observed: a blocky, low, wedge-shaped quadruped with short legs, the head at one end and small pale claws. The outline reads as "badger" even without markings.

**Can't tell:** whether "tap to continue" pauses play, whether the gold variant is random or paid, the reveal animation or sound, and how long the card lasts.

**What we did**
- **The card.** `Client/Controllers/Discovery` adds a journal-plate card for a newly spotted animal, or a newly found favourite food. It shows:
  - the entry number ("No. 12")
  - a kicker ("New in your journal" / "Favourite found")
  - the animal in **side profile** in a ViewportFrame, cloned from the live animal
  - its name
  - one line of what was learned
- **Same order, no economy.** It keeps the name → status → detail → dismiss order, but drops rarity tiers and income rates. We don't have them and won't add them.
- **Not blocking.** The card sits in the right-hand column under the goal card, not over the action. It closes on its own after 5.5 s or when clicked or tapped, and play never pauses.
- **Plate look.** It follows the public-domain Audubon plate reference: a cream sheet, a small numbered corner and the common name below the figure (see [ART_DIRECTION.md](ART_DIRECTION.md#image-references)).

## 3. Throw pose and hub

**Composition**
- Observed: a close over-the-shoulder view of the avatar mid-throw. The throwing arm is raised high and the body is twisted.
- Observed: in the background are fenced plots, a striped market stall, a purple arch or portal, other players' nameplates with "$/s" rates, and dark winged pets.

**Hierarchy**
- Observed: the avatar fills about 40% of the frame. The nameplates float at the top and compete with the sky.

**Silhouette**
- Observed: the arm-up, torso-twist pose reads as "throwing" even in a still frame. That is the anticipation and follow-through principle.

**Can't tell:** whether the pose is an animation asset or procedural, how long it lasts, and whether other players see it.

**What we did**
- **The pose.** `Client/Controllers/ThrowPose` cocks the throwing arm back while charging (further with more power). On release it whips over the top and settles into a follow-through.
- **Testable curves.** The curves are pure functions in `Shared/Feel`. Tests check:
  - the wind-up grows with power
  - there is no single-frame jump larger than about 50°
  - the arm keeps turning one way
  - it is back at rest in 0.55 s
- **No asset.** It needs no animation asset: each client layers it on the shoulder's `Motor6D.Transform` after default animations.
- **Others see it.** Every client poses every thrower from the server's throw broadcast, with a short cock-back for throws it didn't see charge.

## 4. Food landing (carrot and radial streaks)

**Composition**
- Observed: a low camera with the thrown carrot dead centre, alone on open ground, and the target animal small in the background.

**Feedback**
- Observed: faint concentric or radial streaks at the frame edges (a speed-lines or zoom vignette) frame the food.

**Can't tell:** whether the camera zooms or slows, whether there is a landing sound, and how long the effect lasts. Whether the streaks are a game effect or video compression can't be proven from one frame.

**What we did**
- **Landing ring.** We kept the camera alone: no forced zoom, no motion vignette, which can cause motion discomfort. Instead, your own throws get a **landing ring** where the arc will meet the ground (`Effects`, same sampling as the server).
- **Closing in.** The ring closes in and firms up as the food falls (`Feel.landingRing`), so you can watch the animal and still feel the landing coming.
- **Reduced effects.** With Reduced effects on, the ring is shown but doesn't move.

## 5. Animal name reveal ("B_DG_R")

**Composition**
- Observed: the same badger scene. The animal now has a dark outline (a selection highlight).
- Observed: a large partial word, "B_DG_R", with underscores for missing letters, at bottom-centre.

**Inferred:** a fill-in-the-letters reveal of the animal's name.

**Can't tell:** whether it is a spelling minigame, a timed reveal, or what input fills the letters. One frame cannot establish a mechanic, so none is assumed.

**What we did**
- **Writing the name in.** We took only the anticipation idea. On the discovery card the name is *written in* left to right over half a second (`JournalReveal.writing`).
- **Placeholders.** Unwritten letters show as light dots, so the name's length reads at once.
- **Silhouette first.** The animal starts as an ink silhouette and colours in over 0.45 s.
- **No mechanic.** There is no minigame and no input is required.
- **Reduced effects.** Reduced effects shows the finished card at once.

## 6. Flight and biome label ("Forest", "2.19X LUCK")

**Composition**
- Observed: a banana in flight, centred, with a bright white trail line running up the screen toward a corridor of trees.

**Hierarchy**
- Observed: at the top-centre are a large "2.19X" with "LUCK" under it, and a semi-transparent dark strip reading "Forest". Together they cover the upper third of the play view.

**Colour and contrast**
- Observed: neon green checkered ground with repeated stud textures and a bright yellow banana.
- Observed: the trail and the food fight the busy ground for contrast.

**Wayfinding**
- Observed: the narrow corridor (dirt walls on both sides) gives a strong sense of direction.

**Can't tell:** what LUCK does, and whether "Forest" is a zone banner or a persistent label.

**What we did**
- **Arrival banner.** It shows the island name plus your progress there ("Mistfern Grove / 3 of 35 animals noted"). It sits in the upper third, is smaller than the reference, shows for 2.8 s, fades (but not with Reduced effects), and won't repeat for the same island for 90 s.
- **Wayfinding without walls.** We have open islands, not corridors. The `World/Wayfinding` pass gives direction through landmarks instead:
  - a warm stepping-stone path from the spawn to each bridge and to the Feast Cove pier
  - a signpost at each path's end whose board's *pointed shape* faces the destination
  - zig-zag paper lanterns along the bridges
  - placement is checked against the built place (see below)
- **No noisy ground.** The world keeps its smooth plastic and grass materials. No studded or checkered textures were added.

## 7. Training station and HUD ("Press STOP", "+1 XP", "Level 6 4/5")

**Composition**
- Observed: the avatar hangs from a pull-up bar in the centre. A "+1 XP" pops above them and an "XP per rep" sign floats nearby.

**HUD anchors.** Observed, every one competing for attention:
- a "Press STOP" prompt at top-centre
- a red STOP button with a bouncing arrow at bottom-centre
- a blue "Level 6 / 4/5" XP bar across the bottom
- Index and Shop buttons on the left
- strength (43) and money ($94) at bottom-left
- an Animals button on the right
- a cut-off "SE…" sign top-right

**Typography**
- Observed: the progress text ("4/5") is small inside the bar. The button label and the prompt repeat the same word.

**Colour**
- Observed: red (STOP) against green (grass) is the main distinction, which is a red/green pair.

**Can't tell:** the stop timing window, the XP formula, and whether the arrow animates.

**What we did**
- **No second instruction.** No new persistent anchors were added. The throw meter replaces the old bottom power bar, so the bottom-centre keeps only the food bar and the contextual hint. The next action is spelled out once, beside the meter, rather than as a prompt *and* a button.
- **Focus mode.** It removes the goal card and hint while aiming.
- **Discovery column.** Discovery cards share the goal card's right-hand column, so new information always appears in one predictable place.

## 8. Hub navigation (Index, Shop, Animals, "$40M" gate)

**Composition**
- Observed: the avatar faces the camera at centre and hides most of the view. Behind are fenced plots and a gate sign.
- Observed: a paw icon with a large "▲ $40M" price label on the right is partly covered by the Animals button.

**Anchors**
- Observed: left column of square icon buttons (Index, Shop) with labels under them, currencies bottom-left, Animals on the right edge.
- Observed: the world label and the HUD button overlap, and nameplates at the top are cut off by the browser bar (a capture artifact).

**Colour**
- Observed: thick dark outlines on every button make them readable over any background.

**Can't tell:** the gate's unlock rules, and the scroll or selection behaviour of the menus.

**What we did**
- **Labels in the world.** Our signposts carry their text on the board itself (a SurfaceGui), not on floating billboards, so they can't drift under the HUD.
- **Labels that remain.** The world labels that remain (island signs, gates, the bell, the Prep Kitchen) now use Builder Sans in sentence case. Gates read "Locked: Mistfern Grove / 80 coins + 3 research, from the Map tab", not "LOCKED: …". Each label has a shorter draw distance, so fewer show at once.
- **Unchanged.** The HUD keeps its existing left menu column with text labels, at least 44 px touch targets and 4.5:1 contrast.

---

## Checks behind the world changes

There was no Studio session, so the world pass is checked offline against the actual built place (`tests/wayfinding.spec.luau`). The checks:
- Every stone and signpost footprint is on the meadow grass and clear of the spawn pad.
- Nothing new overlaps an existing prop, using an oriented-box (separating axis) test against trees, rocks, flowers, the pond, the kitchen, the gates and the signs.
- Signposts stand beside the path, not on the bridge deck, and their tips point at the destination.
- Lanterns rest on the rail over a post.
- The pass is idempotent.

The first run of these checks caught four real problems, all fixed:
- the lagoon path crossed the pond
- a signpost stood on the beach
- lanterns cut into the rails
- two lanterns clipped the gates

At runtime the pass also skips any stone that would land on a prop, so a rebuilt world can't produce a clash.

`tools/mapview.luau` renders a top-down SVG of the built place, with or without the wayfinding pass, to review the layout without Studio. It draws every visible part's footprint in its own colour.
