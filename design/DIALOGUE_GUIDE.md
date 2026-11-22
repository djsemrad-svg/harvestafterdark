# Writing conversations with Dialogic

Dialogic 2 (the version for Godot 4) is installed in `addons/dialogic`. The version you uploaded
(1.5.1) only works with Godot 3, so the game uses the latest Dialogic 2 from GitHub instead.

## Open the editor
1. Open the project in Godot.
2. Click the **Dialogic** tab at the top of the editor (next to 2D, 3D, Script).
3. On the left you'll see **Timelines** (conversations) and **Characters**.

## What's there already
- Characters: Marguerite and Tobias, in `dialogue/characters/`.
- Timelines: `dialogue/seed_fair_marguerite.dtl` and `dialogue/lantern_tobias.dtl`. They play when
  you talk to the merchant at the Seed and Sprout Fair or the Lantern Creek Gathering.

## Write a new conversation
1. In the Dialogic tab, click **+** next to Timelines and save it in the `dialogue` folder.
2. Add text events. Pick a character so their name shows.
3. Add a **Choice** event for answers the player can pick.
4. Save.

## Make things happen in the game
Add a **Signal** event with one of these arguments:
1. `shop:festival` opens a shop when the conversation ends.
2. `give:moonbloom_seed:2` gives items.
3. `gold:100` gives gold.
4. `friend:ruth:50` adds friendship points.
5. `flag:met_marguerite` remembers something for later.
6. `toast:Your message` shows a message at the top of the screen.

## Hook a conversation to someone
Tell Claude the timeline name and who should say it (and when). Claude adds the line that plays it.
The textbox style is `dialogue/harvest_style.tres` (parchment and the game's pixel font).
