# Art direction: island field notes

The player is a visitor keeping notes on island animals: what each one eats, who trusts them, which islands they've helped restore. The interface should feel like that notebook. It's calm and readable, and it doesn't fight the bright, chunky 3D world for attention.

## References and what was taken from them

Only the principles below were taken from these sources. No art, text, layouts or assets were copied, and no screenshots were reviewed.

- **Alba: A Wildlife Adventure** (ustwo games). Steam store description, fetched via the public appdetails API. It describes "handcrafted visuals", a goal to find every species on the island, and a pace that is "No rush… at your own pace". Taken: the journal as the heart of progression, and no urgency language except during the timed feast.
- **A Short Hike** (adamgryu). Steam store description. It describes peaceful exploration ("hike, climb, and soar… peaceful mountainside landscapes"). Taken: a calm tone, and a small amount of plain text over a colourful world.
- **Game Accessibility Guidelines** (gameaccessibilityguidelines.com, full list). Applied:
  - "Use simple clear language"
  - "Provide high contrast between text/UI and background"
  - "Ensure no essential information is conveyed by a fixed colour alone"
  - "Avoid / provide alternatives to requiring buttons to be held down"
  - "Allow interfaces to be resized"
  - "Ensure interactive elements… are large and well spaced"
- **Roblox Creator Docs.** "Passes", "Paid random items policy guidelines" and the MarketplaceService reference shaped the Shop (see `MONETIZATION.md`).

The original brief named *Throw Food For Animals* as a benchmark. As instructed, it was not researched again. In the third pass the owner supplied eight still frames from it as analysis references. What was observed, what can't be told from a still, and what was turned into original work is in [SCREENSHOT_ANALYSIS.md](SCREENSHOT_ANALYSIS.md). The related video was not opened.

## Image references

The earlier passes only read text. These images were actually viewed (third pass) and their licences confirmed on the source page. Only principles were taken: no image, model or texture is in the repo, and nothing was traced.

| # | Image | Source and licence | What it shows | Principle used |
| --- | --- | --- | --- | --- |
| 1 | Kenney *Nature Kit* preview | [kenney.nl/assets/nature-kit](https://kenney.nl/assets/nature-kit), CC0 | Props in rows on navy. 3–4 base colours (mint, terracotta, pale stone) plus a red accent. Trees made of 1–3 primitives. | Few world colours. Props from simple primitives (already our approach). |
| 2 | Kenney *Nature Kit* sample scene | same page, CC0 | A floating island. A terracotta path winds over a bridge to a waterfall landmark. A red tent and a white marker are the only strong accents. | **One contrasting path colour that leads to a landmark**: the stepping-stone paths and signposts (`World/Wayfinding`). |
| 3 | Kenney *UI Pack* preview | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack), CC0 | Rounded buttons with a darker bottom lip, round slider knobs, filled and empty pips. | Pressable things look different from info panels. Segmented pips for a meter (the throw meter's segments). |
| 4 | Kenney *Cube Pets* preview | [kenney.nl/assets/cube-pets](https://kenney.nl/assets/cube-pets), CC0 | One rounded body per animal. The species is told by 1–2 large add-ons (ears, antlers, trunk). Big friendly eyes. | Species identity lives in silhouette add-ons. The discovery card shows the animal **in profile** so those add-ons read. |
| 5 | Quaternius *Ultimate Animated Animals* | [quaternius.com](https://quaternius.com/packs/ultimateanimatedanimals.html), CC0 | Faceted animals with pale bellies and muzzles. A deer stands raised on a rock. | Two-tone bodies read against the ground. Raised spots work as natural stages. |
| 6 | European badger photo | [Commons: Badger-badger.jpg](https://commons.wikimedia.org/wiki/File:Badger-badger.jpg), BadgerHero, CC BY-SA 3.0 | Low wedge body, stub legs, nose down. The face stripes are the one mark people recognise. | Silhouette first, one mark second: the discovery card starts as an ink silhouette, then colours in. |
| 7 | European hare photo | [Commons: Lepus europaeus (Uitkerke)](https://commons.wikimedia.org/wiki/File:Lepus_europaeus_(Uitkerke).jpg), Hans Hillewaert, CC BY-SA 4.0 | Tall black-tipped ears about half the body height. A warm front and a cooler back. | The ears anchor the silhouette, and ear pose shows mood (already used by `AnimalMotion`). |
| 8 | J. W. Audubon, *American Badger*, 1845 plate | [Commons file](https://commons.wikimedia.org/wiki/File:American_Badger_(Meles_Labradoria)_from_the_viviparous_quadrupeds_of_North_America_(1845)_illustrated_by_John_Woodhouse_Audubon_(1812-1862).jpg). The 1845 artwork is public domain; this scan is by rawpixel, CC BY 2.0. | One animal in side profile on cream paper, a faded landscape, "No. 10" in a corner, the name centred below. | **The journal-plate card**: cream sheet, entry number, side-profile animal, name, one line of notes (`Client/Controllers/Discovery`). |

Credit for the CC BY / CC BY-SA images (#6–#8) is given here. None of them are redistributed.

## Palette

Defined in `Client/Controllers/Ui.luau`. The world keeps its own saturated colours, and the HUD stays muted so the two don't compete.

| Token | RGB | Use |
| --- | --- | --- |
| Panel (paper) | 244 237 224 | panels, goal card |
| Card | 252 248 240 | rows, toasts |
| PanelDark (ink green) | 38 52 48 | HUD chips, side menu, selected tab |
| Ink | 40 36 32 | body text |
| Muted | 98 92 82 | secondary text |
| Primary (moss) | 70 112 68 | action buttons, progress |
| Accent (clay) | 176 84 52 | the thing that is selected |
| Info (tide) | 42 92 114 | feast banner |
| Good / Warn / Bad | 56 120 80 · 150 92 24 · 160 58 48 | toast edges and banners |

Measured contrast (WCAG formula): white on moss 5.7:1, on tide 7.3:1, on clay 5.0:1, on warn 5.5:1. Ink on paper 13.2:1, muted on paper 5.7:1. Disabled button text 4.7:1. Every text pair is at least 4.5:1.

## Rules

- **Type.** Builder Sans: Bold for titles, SemiBold for labels, Medium for body. No novelty display font.
- **Surfaces.** Flat fills, 8px corners and 1px hairlines in `Rule`. No gradients, glows, drop shadows or emoji. The only light effects are the existing world bloom and the companion's small lantern light, which Reduced effects turns off.
- **Selection.** Always a shape plus a colour:
  - the open tab has a dark fill and a clay underline
  - the food in hand has a clay outline and a tab below it
  - toasts have a coloured edge, and the wording says what happened
- **Copy.**
  - Sentence case and short sentences.
  - Say what happened or what to do next ("Learned to make Clover Bun.", "Bar is full").
  - No "!" except the animals' own surprise emote, and no ALL CAPS.
  - Locked actions start with "Locked:" and give the reason.
- **Throw meter.** A vertical gauge of 10 segments right of the aim point, never over it. It shows a notch, a percentage, the predicted outcome in words and the real input to press next. A predicted catch adds a heavier clay outline. There is no red-to-green ramp.
- **Discovery card.** A journal plate in the right-hand column: entry number, kicker, side-profile animal (an ink silhouette first), the name written in, and one line of notes. It never blocks play.
- **World labels.** Builder Sans, sentence case, shorter draw distances. Signposts carry their text on the board itself. Paths are one warm stone colour against the grass and always end at a signpost or bridge.
- **Motion.** Every action has anticipation and recovery: the arm cocks back with power and follows through, and the landing ring closes in as food falls. Reduced effects keeps the information and drops the motion.
- **Companions.** They use the same primitive-part, smooth-plastic construction as the island animals, so they read as residents rather than store items. The Lanternkit's paper lantern is the one neon part.
