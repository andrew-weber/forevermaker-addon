# ForeverMaker

ForeverMaker is a quest addon for WoW Classic Era and WoW Forever. The website at [forevermaker.xyz](https://forevermaker.xyz) stores the quest. This addon tracks it in the game. Quests move between them as text you copy and paste.

## Install

1. Download this repository and copy the `ForeverMaker` folder into your game's `Interface/AddOns` folder. Copy the folder that contains `ForeverMaker.toc`.
2. Enable ForeverMaker on the character screen, then reload.

Type `/fm` or `/forevermaker` to open the quest log.

## Frames

Draw the quest log with our own frames. Forever does not include Classic's `QuestLogTitleButtonTemplate`. Inheriting that template makes `CreateFrame` fail, the list stops drawing, and the log stays at zero quests even though the quest was saved. This has happened twice. List rows are plain buttons with their own text, highlight, and check mark. Do not inherit a Blizzard quest-log template unless it is confirmed on both Classic Era and Forever.

## Take a quest into the game

1. Open a saved quest on the website and choose **Export Quest**. That copies a short text block.
2. In the game, open the quest log and choose **Import**.
3. Paste the block, choose **Check**, then **Save**.

Pasting the same quest again keeps the progress you already have. A newer copy of that quest replaces it and starts the counts over. An older copy is refused.

## What the addon counts

A kill goal advances when this character, or someone in the party, lands the killing blow.

- When the game shows the creature id, the addon matches that id.
- When the game hides the id, the addon waits a few seconds for the experience line that names the creature. The line on its own adds nothing. A blow with no line adds nothing. One death counts once.
- A level limit on the quest blocks the kill once this character is past it.
- A hunter pet's killing blow is missed, because the game sends no party-kill event for it.
- A collect goal is one item. It is complete while that item is in your bags, in the bank, or worn, including pieces you already had when you saved the quest. Giving the item away opens that goal again.
- A loot goal stays on the log. That goal is a count of items, and those counts wait for a later version.

When every goal is full, the addon records who finished it, their level, class, and worn gear.

## Bring a finish back to the website

The game writes `ForeverMaker.lua` for this character when you log out, quit, or `/reload`. The file is in that character's `SavedVariables` folder. A crash before then can drop the counts from the current session.

Sign in on the website, open **Complete quest**, and paste the whole file. Finished quests are saved to your account. Quests that are still open stay in the file and are left out of the save.

The website checks the quest, the revision, and the goals before it keeps a finish.
