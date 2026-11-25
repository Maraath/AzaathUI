# Changelog

## 0.1.3

- Releases are now packaged and uploaded to CurseForge automatically from GitHub.
- Assorted fixes and improvements across the HUD, map, action camera and options.

## 0.1.2

### New

- **"Blizzard" skin:** keeps the game's default player and target frames. The Azaath target auras and target cast bar are turned off, since the default target frame has its own. Player buffs, player cast bar and XP bar stay Azaath.
- **"Blizzard" bar layout:** keeps the game's default action bars, with their micro menu and bags. The Azaath bars, stance/pet bars and micro menu are not built.
- **"Blizzard" nameplate style:** keeps the game's default nameplates. AzaathUI stops changing nameplate sizes and restores the world name settings.

All three are available in the options panel and the setup wizard, and apply after a reload.

- **Undiscovered flight points:** AzaathUI now remembers, per character, the flight points you already know (updated every time you talk to a flight master). Missing ones show on the world map with a bigger amber ring drawn above quest pins, and on the flight master map with an amber pulsing ring, their name and a "not yet discovered" tooltip.

### Known limitations

- The rotation assistant only lights up Azaath bars, so it does nothing with the "Blizzard" bar layout.
- With the "Blizzard" bar layout, the game's XP bar shows alongside the Azaath one.
- With the "Blizzard" nameplate style, features drawn on Azaath nameplates are not shown: quest and service markers above NPCs and enemies, the loot beam on corpses and the cast ring over world objects. Map pins and the 3D waypoint are not affected.

## 0.1.1

### New

- **Rotation assistant (Warrior):** lights up the next ability on your bars, with sounds, shouts and cast effects. Toggle it in the options panel.
- **Camera director:** the camera adapts to the situation (combat, boss, mount...) and remembers the zoom distance used in each one. The shoulder offset follows the zoom, abilities get their own camera moves (charge, whirlwind, heavy strike, shout) and the camera shakes when you take damage.
- **Reforged bars (Option 4):** the concept-art action bars are now a bar choice for any skin, not only Azaath Reforged. Each strip moves on its own, and the stance tabs sit on top of the left strip.
- **Azaath Reforged HUD:** the center frame (health, resource and XP) is now a standalone piece with a new glow.

### Map and quests

- Undiscovered flight points are bigger, with an amber ring, and their tooltip says "Ainda não coletado" (not yet discovered).
- New "Pins de quest" filter to show the game's original quest pins instead of ours.
- The map quest panel has four buttons and a resize handle; its size is saved.
- The focused quest's area disappears once the quest is turned in or abandoned.
- The quest tracker uses the map's green pin for quests ready to turn in.
- Zone level ranges are worked out from the quests in each zone.

### Fixes

- **Flight master:** the Blizzard window no longer closes the flight session on the server, which could disconnect you when taking a flight. The chosen destination is now always the right one.
- **NPC nameplates:** fewer false vendors and services (only the first subtitle line counts, and words must match at the start). Map quest pins now show above the NPC.
- **Target on nameplates:** the aura around the bar, which blurred the end of the health bar, was replaced with rising embers.
- **Square minimap:** buttons around the minimap follow the straight edge.
- **Action Camera:** turning it off now resets every camera setting to the game's factory defaults.

### Cleanup

- Removed the old quest guide code, unused filters from the Drops tab and dead functions in the chat, the radial menu and the options panel.
- Removed textures that were no longer used, making the package smaller.

## 0.1.0 (first public release)

First release of AzaathUI for WoW Forever.

- **HUD:** top compass, unit frames and centered action bars. Azaath, Black Desert (Zerker), Modern and Classic skins.
- **Nameplates:** enemy bars with quest, target and mouseover markers, rare and elite frames, and a loot beam on corpses.
- **Combat:** floating combat text, spiral cast bar, auras and action camera (FreeLook).
- **Custom world map** in the Expedition frame: quests, dungeon entrances, Rare Scanner and the magic path, whose routes live in the `AzaathUI_Nav_EK` and `AzaathUI_Nav_Kalimdor` addons.
- **Character sheet:** stats, talents (Crucible), reputation, skills, Sanctuary with the Dungeons tab, and Grimoire.
- **Bag:** Azaath skin, Equipped panel (astrolabe), item lock and item card with auction price.
- **Professions:** Artisan's Table.
- **Eye of Azaath:** radial menu, Loremaster panel and setup wizard.
- **Per-character database.**
