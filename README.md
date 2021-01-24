Resource Highlighter
====================
-- Original mod by Vamalo --

This mod looks for resources in areas that you've charted and highlights them on the map using a highly visible glowing treasure box.  Although the mod has little value in Vanilla, it's helpful for mods that add dozens of new resources with similar map colors.  I designed the mod with speed in mind.  The mod scans new chunks in the background as you explore so that it's able to immediately show you a resource of interest.

Directions
==========

Press SHIFT + H (or the key you've configured for Resource Highlighter) to open the menu.
The menu displays every vanilla and modded resource available in your game.
Each row shows you the ore (or fluid) produced and a list of machines capable of mining it.
Choose which resources you want to find by clicking on the boxes beside them.
The mod will place a treasure box beside every resource patch that your team is able to see.
When you're finished, close the menu by clicking the 'X' or by pressing SHIFT + H.  The treasure boxes will disappear.
Click 'All' to check all boxes.
Click 'None' to uncheck all boxes.
Click 'Refresh' to update the treasure boxes after revealing more of the map or changing the settings (A refresh also happens automatically each time you open the menu or make a new selection.)

Limitations
===========

1. Each person on your team will see your treasure boxes in addition to their own.
This is an unfortunate limitation of the Factorio API (add_chart_tag() accepts a force parameter, not a player parameter.)

2. The mod is unaware of changes to resources made by other mods such as Ore Eraser.
If you erase a resource patch and open Resource Highlighter, a treasure box will still appear beside it.
To work around the problem, use the /rh_rescan console command.  Typing /rh_rescan in the console will reset the mod's internal data
and rescan every chunk for every resource.

Internal Overview
=================

When a chunk is generated, the mod schedules it for a scan.  The scan finds every resource entity in that chunk and remembers three pieces of information:

1. the number of resource entities found
2. the sum of their X coordinates
3. the sum of their Y coordinates

When the player opens or refreshes the Resource Highlighter, the mod looks for groups of connected, charted chunks containing each selected resource.  For each group, the mod calculates the sum of the three pieces of information above, (1), (2), and (3).  Dividing (2) by (1) and (3) by (1) gives the coordinates of the group's centroid.  When a resource entity is depleted, the mod calculates its chunk, decreases (1) by 1, decreases (2) by its x coordinate, and decreases (3) by its y coordinate.

This approach has the advantage of being fast and minimizing the amount of data that the mod needs to save.  The downside is that the three sums are accurate only if the mod is able to track every creation and deletion of a resource entity.

Changelog
==========
See Changelog tab
