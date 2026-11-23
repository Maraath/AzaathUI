# Dungeon Master

A lightweight, dependency-free dungeon and raid journal for **WoW Forever**.
Prepare your quests, check rewards and access requirements, then follow bosses and loot through the run.
Built for keyboard/mouse and gamepad, with an integrated virtual keyboard for supported languages.

![icon](media/icon.png)

## Features in 2.0.0

Version 2.0.0 completely overhauls the interface, from the dungeon browser and quest views to the boss and loot panels.

- **Redesigned journal.** Browse artwork cards grouped by your level, coming up and below your level, or switch to raids and favorites. Search dungeons, bosses, quests and items. Scarlet Monastery has four wings; Lower and Upper Blackrock Spire are separate entries. The journal selects your current instance and shows raid lockouts and completion.
- **Dungeon readiness.** See missing outside quests, a separate inside count, quests already in your log and completed quests. Open the readiness list to jump to a quest. Ready-to-turn-in quests count as completed; dismiss a quest, chain or remaining steps and restore them later. Optional breadcrumbs and repeatables are identified. Readiness and completion notices provide visual and chat feedback.
- **Quest chains.** A unified list separates standalone quests, expandable chains and class-specific quests. Track prerequisites and follow-ups, progress counts, level restrictions and class locks. Other-class chains start collapsed.
- **Quest details and rewards.** See objectives, pickup and turn-in locations, XP, money and items. Open the dungeon reward overview, hover items for tooltips, follow quests, share eligible quests and see party members on the same quest. Shift-click quests or items to link them in chat; recognized quest names in chat become links locally.
- **Map navigation.** Pin entrances, quest givers, quest-starting drops and turn-ins where coordinates are known. Nearby quests at the same NPC appear as links in chat. Pins toggle off or clear on arrival. An optional in-world navigation assistant shows direction and distance.
- **Keys, access and Legacy.** Banner badges show attunements, keys and special requirements, including party key information shared by other Dungeon Master users. The Legacy shield displays Spelunker progress and opens the relevant challenge. Earlier dungeon clears can be recognized from game statistics.
- **Bosses and loot.** Portrait cards show boss levels, kill progress, the next encounter, quest markers, rare spawns and drops. Class filters dim unsuitable loot. Multirow loot supports gamepad navigation. Forever quests, bosses and items are identified with a blue F where known.
- **Favorites.** Mark boss drops and quest rewards with silver or gold stars per character. Browse them in Favorites, with the same item navigation and tooltips; this view does not apply a class filter.
- **Boss timeline.** Follow kills and the next boss in the current run, including encounters needed for quests. Click a portrait to open its loot. Move, resize, collapse or hide the timeline.
- **Raids and tactics.** Onyxia has loot, attunement chains and encounter tactics. Hyjal Summit and Barrow Deeps have boss listings and a Tactics tab for upcoming coverage. Dungeon maps and expanded raid coverage remain on the roadmap.
- **Enhanced Loot Window.** Follow active need/greed/pass rolls, current leaders, final winners and roll details. Favorites keep their stars; tooltips and item links are available. Dismiss entries and see winner notices. Trash notices are limited to rare quality or higher.
- **Threat.** Customize the group-and-pet threat window, bars, text, colors and visibility. Quick Threat beside the target shows the aggro holder and warns when someone approaches 80%, with a rising indicator and a stronger warning for your character.
- **Gamepad-ready controls.** Navigate dungeon sections, quests, rewards, class filters, boss loot, favorites, options and window-size presets with native button prompts. Selection scrolls into view, shoulder buttons switch the content tabs, and Back returns through the journal before closing it. Opening the world map from the journal hands control back to the game UI.
- **Integrated virtual keyboard.** Search using the controller in English, Portuguese, Spanish, German, French, Italian or Russian. Regional letters, UTF-8 backspace and cursor movement are supported. Live results keep selection on the keyboard until confirmation. Square/X deletes; Triangle/Y selects Search without submitting. Prompts follow the connected controller.
- **Options and localization.** Configure a persistent opening shortcut under the game's **Key Bindings > Dungeon Master** category. Use the gear, minimap, addon compartment or game Settings launcher. Window scale is saved, with gamepad presets from 70% to 130%. The interface follows the client language across ten locales; a short login greeting and update notices keep players informed.
- **Community data.** Newly observed boss drops can be learned locally and announced for reporting. Quest givers encountered while playing fill local gaps. Corrections include full priest coverage for Blood of Morphaz, exclusion of the level-60 AQ scepter branch from Sunken Temple's leveling list, and Meshlok the Harvester in Maraudon.

## Controller search and languages

The interface is translated into English, Português, Español, Deutsch, Français, Русский, Italiano,
한국어, 繁體中文 and 简体中文. Game names use client-localized data where available, with English fallbacks.
Community corrections to translations are welcome.

The virtual keyboard follows the client language and supports the seven Latin/Cyrillic languages listed above.
Korean and Chinese clients use the normal search text field; custom Hangul and Chinese composition are not included.
There is no player-facing language switch. Developer language previews belong to the separate development addon.

## Usage

- `/dm` — open/close the window
- `/dm help` — list the commands in chat
- `/dm minimap` — show the minimap button again
- `/dm timeline` — show/hide the boss timeline (inside a dungeon)
- `/dm threat` — show/hide Quick Threat
- `/dm options` — open the options (minimap button, boss timeline, threat, loot banner, feedback)
- Minimap button: click to open, right-click to pick a dungeon or open options, drag to move.
- Opening shortcut: Key Bindings > Dungeon Master > Open/Close Dungeon Master.
- Options: the gear in the window, or Esc > Options > AddOns > Dungeon Master > Open options.
- The game's Settings page also offers Open Dungeon Master to open the journal directly.
- Gamepad: select the search field to open the virtual keyboard in supported locales. Use Square/X for backspace, Triangle/Y to select Search, and confirm to enter the results. Native prompts show the buttons for your device.

## Requirements

World of Warcraft: Forever. DungeonMaster requires no other addons.

## Where the data comes from

1. **`Data.lua`** — classic dungeon quests, quest givers, coordinates, prerequisites, rewards and objectives,
   generated from the [cMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0). Quest-giver
   positions are converted to map coordinates with the game client's own map tables.
2. **The game** — dungeon list, level ranges, bosses and artwork from the client's own tables; quest names in
   your language, XP and money rewards,
   completion status, the zone a quest giver stands in, and live rewards for quests in your log.
3. **`Curated.lua`** — hand-curated data for new WoW Forever content and corrections to the classic data, partly
   from what Questie players see in WoW Forever ([QuestieDB](https://github.com/Questie/QuestieDB), GPLv3),
   cross-checked with [foreverchanges.pro](https://foreverchanges.pro).
4. **What you see while playing** — quest givers you talk to fill small gaps on your own machine.

## Feedback & support

Found a bug or missing quest? Leave a comment on the CurseForge page.

Special thanks to my guild brothers in **Grey Parse (Parse Cinza)**. Your feedback and suggestions made this addon possible.
If you enjoy the addon, you can support development at [ko-fi.com/malkdev](https://ko-fi.com/malkdev).

## Credits

- **Blizzard Entertainment** — World of Warcraft and the addon API.
- **CMaNGOS** — the [classic-db](https://github.com/cmangos/classic-db) quest, NPC and spawn database (GPL-3.0).
  Thanks to all its contributors.
- **Questie** — inspiration for how a quest database helps players, and the WoW Forever data its players collect
  ([QuestieDB](https://github.com/Questie/QuestieDB), GPLv3): quest givers, places and boss loot of the new content.
  Thank you, Questie team!

## License

DungeonMaster is free software under the [GNU General Public License v3.0](LICENSE): you may use, change and
share it, as long as what you share stays under the same license and keeps the credits.
World of Warcraft content (names, texts, IDs) belongs to Blizzard Entertainment. This project is not affiliated
with Blizzard, CMaNGOS or Questie.

The addon source is included in the download and installed under `Interface/AddOns/DungeonMaster`.
