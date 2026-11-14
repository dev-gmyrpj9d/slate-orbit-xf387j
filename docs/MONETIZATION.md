# Optional passes

Everything in the game stays free. The three passes add a companion, a cosmetic or a convenience. None of them changes coins, research, trust or catch rules, and `tests/monetization.spec.luau` enforces that.

## Lineup

| Key | Name | Kind | Exactly what you get |
| --- | --- | --- | --- |
| `lantern_egg` | Lantern Egg | Companion | Hatches a **Lanternkit**, every time. You hatch it once in the Shop, then show or hide it whenever you like. Other players see it follow you, and it hops when you feed an animal. |
| `painters_kit` | Painter's Kit | Cosmetic | Ribbon, Petal and Ink Line trails on your thrown food. Everyone nearby sees them. |
| `field_satchel` | Field Satchel | Convenience | Pin limit goes from 4 to 6. Every food is still in the Pantry for everyone. |

## Why there is no randomness

The Roblox "Paid random items policy guidelines" page lists "Hatch an egg for a pet" as a paid random item. Paid random items must show every outcome with its odds. The Lantern Egg has exactly one outcome, and its first detail line says so ("Always hatches a Lanternkit. There is no random outcome."). The test suite checks that this wording stays and that `Passes.luau` uses no randomness.

## How it works

The design follows the Creator Docs "Passes" guide and the MarketplaceService reference.

- **Ownership.** `Server/Services/PassService` calls `UserOwnsGamePassAsync` when each profile loads. It retries a bounded number of times, and ownership is checked on the server, as the guide recommends.
  - A definite "owned" or "not owned" updates `profile.passes`.
  - If the check fails, the saved value is kept as a fallback.
  - Unconfigured passes are always treated as not owned.
- **Buying.** The client sends `BuyPass`. The server checks that the pass is configured and not already owned, applies a 3s cooldown per player and pass, and then calls `PromptGamePassPurchase`.
  - `PromptGamePassPurchaseFinished` (engine-fired) with `wasPurchased` grants the pass immediately. The reference says the ownership cache updates on this event.
  - A join-time check that is still running can't take back a pass bought this session.
- **Equip.** `HatchEgg`, `SetCompanion` and `SetTrail` are validated by `Shared/Passes` against server-confirmed ownership. If ownership is lost, shown cosmetics are cleared and extra pins are trimmed. Hatch records are kept, so a restored pass restores them.
- **Saved data.** Save schema v4 adds `passes` and `cosmetics`, with a v3→v4 migration. Unknown keys are dropped when a save is cleaned up.
- **Multiplayer.** The server publishes `Companion` and `Trail` player attributes. Each client draws companions locally (`Client/Controllers/Companions`): at most 12, within 160 studs, nearest first. The server does no companion work.
- **Prices.** Prices are never stored. `Client/Controllers/Shop` calls `GetProductInfoAsync(id, Enum.InfoType.GamePass)` and shows `PriceInRobux` only if `IsForSale` is true. Otherwise the Shop says "Not on sale yet", "Not on sale right now" or "Price unavailable", with no Buy button.

## Configure (Studio / Creator Hub, by the owner)

1. Create the three passes in Creator Hub > Monetization > Passes. Set the name, a 512×512 icon (keep the important details inside the circle) and the price there. Nothing here sets prices.
2. Copy each pass's asset ID ("Copy Asset ID") into `PassId` for that key in `src/ReplicatedStorage/Shared/Config.luau` (`Config.Passes`).
3. Rebuild with `lune run tools/build.luau`, or edit the ModuleScript in Studio.

Until step 2 is done, every `PassId` is `0`, the Shop shows "Not on sale yet" and the server refuses to prompt. No IDs or prices were invented, nothing was published, and no marketplace settings were changed.

## Studio-only checks still needed

1. With real IDs set, in Play Solo:
   - The Shop shows the live price.
   - Buy opens the Studio test-purchase dialog.
   - Confirming grants the pass with no rejoin.
2. Hatch the egg, show and hide the Lanternkit, and switch trails.
3. Run a 2-player local server and check that the other player sees the companion and trails.
4. Rejoin and check that ownership is re-checked and cosmetics come back.
5. Remove a test ID and check that its cosmetics and extra pins disappear.
6. Use a mobile emulator to check that the Shop previews fit the panel.
