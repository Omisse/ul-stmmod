# SmartThreadManager
> Mod for [Upload Labs](https://store.steampowered.com/app/2881650/Upload_Labs/) game

![Icon](icon.png)

## About
I started this just to try modding in general for the first time, turned out to be quite an interesting project to work on.
Despite the mod name, its code is quite universal and with little tweaks on scene or in container logic can fit for many cases.
What else you want to know?

## Features
### If you want to know _how_ it really works, read [this](details/general_mechanic.md) article
 - Automated and somewhat optimized management of CPU speed resource in-game
 - Demand-based resource distribution
 - Rerouting of any excess resources to all connected storage nodes evenly, as it works for all connections in base game
 - The node is locked behind the "Thread Manager" upgrade from base game.


## Installation
- ### Steam - Recommended
 1. [Subscribe on the workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3631577623)
 2. Launch the game.

- ### Manual
 1. Download **kuuk-SmartThreadManager.zip** from the [release page](https://github.com/Omisse/ul-stmmod/releases/latest)
 2. Create **"mods"** folder  in your game directory.
 3. Put the archive into the folder.
 4. Launch the game.
 
   - If you choose to unpack the archive - just put the **"mods-unpacked"** folder you've got into game directory.
   - Go to step 4.
   
## Compatibility
 | Requirement | Version |
 |-------------|---------|
 | Upload Labs | 2.0.17+ |
 | Mod Loader  | 7.0.0+  |

 ### [Known issues](https://github.com/Omisse/ul-stmmod/issues)

# ⚠️ **No compatibility guaranteed with any mod that overrides that vanilla functionality:**
 | Area | Context |
 |------|---------|
 | save  | (game, node, config) |
 | load  | (game, node, config) |
 | place | (window) |
 | menu  | (windows menu, custom buttons etc) |
  
# ⚠️ **Spare backup is always useful.**

## License
This project is licensed under the [MIT License](LICENSE)

