# BetterProfessions

BetterProfessions is a small World of Warcraft Retail addon that extends Blizzard's profession interface. It adds useful details to the crafting-order list and shows the specializations that affect the quality of the selected recipe.

The player-facing CurseForge description is available in [CURSE.md](CURSE.md).

## Features

### Crafting-order list

- Net commission after the Consortium cut.
- Estimated profit rounded to whole gold, with an exact breakdown in the tooltip.
- Price data from Auctionator, TradeSkillMaster, or Oribos Exchange.
- Item and currency rewards from patron orders.
- Required reagents not supplied by the customer.
- Red highlighting when the character does not own enough of a reagent.
- Inventory checks across valid reagent qualities, bags, reagent bank, and Warband bank.
- Concentration required to reach the order's minimum quality.
- An empty reagent column when the customer supplied everything.

Order previews use the same `row.option` state as Blizzard's ScrollBox rows. This keeps each preview attached to the correct order after sorting, list updates, and row reuse.

### Recipe specializations

- A compact side panel displayed when a recipe is selected.
- All known related nodes that can affect skill for the recipe.
- Current and maximum rank for each node.
- Current and maximum skill bonuses.
- Node descriptions and threshold bonuses in tooltips.

The recipe-to-node mapping is stored in `Data/RecipeSpecializations.lua`. Names, icons, descriptions, and current progression are retrieved through the WoW API.

## Dependencies

BetterProfessions has no required dependencies.

Auction profit can use any one of the following addons as a price source:

- Auctionator;
- TradeSkillMaster;
- Oribos Exchange.

All non-pricing features continue to work without an auction addon.

## Commands

- `/bp` — show help;
- `/bp orders` — toggle crafting-order previews;
- `/bp specs` — toggle the recipe specialization panel;
- `/bp reset` — reset settings.

Use `/reload` after toggling a module.

## Project structure

```text
BetterProfessions.toc
Core.lua
Locales.lua
Data/
  RecipeSpecializations.lua
Modules/
  OrderList.lua
  RecipeSpecializations.lua
scripts/
  Validate.ps1
  Deploy.ps1
  Watch.ps1
  Package.ps1
  Generate-SpecializationData.ps1
```

## CI and releases

- `.github/workflows/ci.yml` validates the addon and creates a test ZIP.
- `.github/workflows/release.yml` runs the BigWigs Packager for `v*` tags.
- The release tag version must match `## Version` in `BetterProfessions.toc`.
- CurseForge publishing requires a project ID in `.pkgmeta` and the `CF_API_KEY` secret.
