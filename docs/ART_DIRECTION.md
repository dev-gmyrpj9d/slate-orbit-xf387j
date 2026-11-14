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

The original brief named *Throw Food For Animals* as a benchmark. As instructed, it was not used again.

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
- **Companions.** They use the same primitive-part, smooth-plastic construction as the island animals, so they read as residents rather than store items. The Lanternkit's paper lantern is the one neon part.
