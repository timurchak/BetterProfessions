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

## Local development

PowerShell 7 or Windows PowerShell 5.1 is required.

Create the Git-ignored `.deploy.local.ps1` file from `.deploy.local.ps1.example`:

```powershell
$BetterProfessionsWowRoot = "F:\G\World of Warcraft\_retail_"
```

Alternatively, pass `-WowRoot` directly or set the `WOW_RETAIL_PATH` environment variable.

Main commands:

```powershell
./scripts/Validate.ps1
./scripts/Deploy.ps1
./scripts/Watch.ps1
./scripts/Package.ps1
```

- `Validate.ps1` validates the TOC, Lua files, and version metadata.
- `Deploy.ps1` validates the project and copies runtime files to `Interface/AddOns/BetterProfessions`.
- `Watch.ps1` repeats the local deployment when runtime files change.
- `Package.ps1` creates a release-ready ZIP in `dist`.

## Updating specialization data

After a major profession update, the mapping can be regenerated from an installed copy of CraftSim:

```powershell
./scripts/Generate-SpecializationData.ps1 `
  -CraftSimRoot "F:\G\World of Warcraft\_retail_\Interface\AddOns\CraftSim"
```

CraftSim is only used as a development-time data source. Players do not need to install it.

## CI and releases

- `.github/workflows/ci.yml` validates the addon and creates a test ZIP.
- `.github/workflows/release.yml` runs the BigWigs Packager for `v*` tags.
- The release tag version must match `## Version` in `BetterProfessions.toc`.
- CurseForge publishing requires a project ID in `.pkgmeta` and the `CF_API_KEY` secret.

## Inspiration

The enhanced crafting-order list was inspired by ProfessionShoppingList, while the related-specialization view was inspired by CraftSim. BetterProfessions does not require either addon at runtime and provides its own implementation on top of Blizzard's standard interface.
