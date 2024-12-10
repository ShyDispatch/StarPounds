
# StarPounds

A mod for Starbound that adds body shapes of various sizes and weight gain. Watch your belly swell as you eat, food or others, or subject the npcs of the various worlds to it instead.

StarPounds is designed to mesh with (and ideally enhance) the existing Starbound gameplay loop.


## Features

- Weight gain, and a whole suite of fat-based mechanics.
- Two brand new species, Throgs and Mootants.
- Hundreds of new objects, including weight scales, treadmills, feeding tubes, interactables, giant foods, and both functional and purely decorative objects.
- Innumerable new fattening foods and other consumables.
- Several new fat themed weapons, tools, and traps.
- Three new Throg/Fat themed techs, one for each slot.
- Plenty of new tiles and liquids.
- Separate fat-themed hub for mod content.
- Brand new USCM-themed intro mission for Mootants, including an alternative to the Broken/Protector's Broadsword.
- New Floran gluttonist dungeon, with more dungeons planned in the future.
- Fully fledged skill system for upgrading fat-based attributes & abilities.
- Accessories that boost fat-based attributes.
- Multiple milk-based skills and mechanics.
- Full featured vore mechanics, with both prey and pred functionality.
- Options to enable or disable features of the mod.
- Full compability for multiple modded species.


## Installation

Installation is the same as any other Starbound mod. Simply extract the .pak files from the mod archive directly into your `/Starbound/mods` folder. __Do not put the entire ZIP file into the mods folder.__

The `/mods` directory should look like the following:
```
mods_go_here
StardustLite.pak
Starpounds.pak
Starpounds-ExtendedRaces.pak
Starpounds-Throgverse.pak
...
```
If you have `QuickBarMini` or `Stardust Core` installed either within your mods folder or on the steam workshop. Remove them so they do not conflict with `StardustLite` which is essential.

## FAQ

#### How do I enable the mod?

Assuming you've installed Stardust Core Lite correctly (Bundled in the mod archive, but you can also download it from the either the [Workshop](https://steamcommunity.com/workshop/filedetails/?id=2512589532) or [GitHub](https://github.com/zetaPRIME/sb.StardustSuite)), you should have a menu icon to access the QuickBar in the right sidebar (☰). Click the StarPounds button to bring up the mod's quick menu, and click the green button at the bottom to toggle the mod.

#### How do I unlock skills?

You can unlock skills at an [Infusion Table](#how-do-i-get-an-infusion-table) using [Experience](#how-do-i-get-experience).

You can also access the skill menu from the QuickBar at any time, however you won't be able to unlock skills ones without an [Infusion Table](#how-do-i-get-an-infusion-table).

#### How do I get Experience?

Experience is gained by eating. The amount gained is directly correlated to how much food an item provides, multiplied by its rarity:
| Rarity    | Multiplier |
| :-------- | :--------- |
| Common    | 1x         |
| Uncommon  | 1.25x      |
| Rare      | 1.5x       |
| Legendary | 1.75x      |
| Essential | 2x         |

Your progress to the next level can be seen in the Skills menu. Each additional level takes more Experience than the last, so it's recommended you spend your levels instead of accumulating large amounts.

#### How do I get an Infusion Table?

You can craft an Infusion Table at the [Inventor's Table](https://starbounder.org/Inventor%27s_Table).

#### How do I get Accessories?

Accessories are found as random loot, and themed accessories have a higher chance to spawn in some of the mod's dungeons. You can also purchase jewellery boxes from random Throg merchants you encounter, or directly from Mossarrow in the Hog Diner.

#### Can I use Big Fatties with Starpounds?

Big Fatties is the predecessor of Starpounds, and has undergone many changes such as an entire rewrite of the code. To summarize, it is the outdated version of Starpounds and cannot be used together.

#### Can I use Big Fatties addons with Starpounds?

Any unofficial addons made for Big Fatties will not work correctly with Starpounds.

#### The Quickbar for Starpounds doesn't do anything when I click on it.

You have either Quickbar Mini, Stardust Core, Community Framework, or any other potential Quickbar alternative that is not Stardust Lite. Any of these will conflict with Stardust Lite, and Starpounds depends on the Metagui that Stardust Lite has over other Quickbar mods.

#### How do I fill the Feeding Tube?

Drop an item of liquid, not pouring liquid into the world but the item in your inventory, in front of the Feeding Tube. Either by dragging it out of your inventory or using the Drop Item key while holding it. Usually the [Q] button by default. If the dropped item is not in front of the Feeding Tube it may not be picked up.

#### How do I get to the Hog Diner?

The Hog Diner will be available to warp to from your ships teleporter.

#### Clothing won't grow with size

Make sure clothing is put into the cosmetic armor slots of your ui, the place where the fat armors show up. If it doesn't stick in, that means that piece of clothing is currently not supported for weight gain.

#### How do I vore?

Once you unlock a vore skill, you can either use the hotkey for it if you have either OpenStarbound or StarExtensions installed. Or click on the mouth button that shows up in any vore skill tree to get the vore tool.

#### Food doesn't give xp or cause weight gain

Do prevent issues with mods overwriting the food lua, or not having to patch every modded food item. A script is applied to all food items whenever it's clicked on. This means the script will not run if you eat food that pops up in your hotbar that you didn't click.

#### Does Starpounds work with Cutebound?

No. It Overhauls too much and causes inconsistences.
We have a modified version that does some reversions and some improvements.

#### Why won't npcs get fatter/why can't I eat npcs at the Outpost?

Npcs at the Outpost, Hog Diner, or any other form of hub area generally has protection that prevents them from being fattened up or vored.

#### What species are supported by Extended Races?
Currently, the following species are supported:
- [Avali](https://steamcommunity.com/workshop/filedetails/?id=729558042)
- [Aegi](https://steamcommunity.com/sharedfiles/filedetails/?id=850109963)
- [Saturnian](https://steamcommunity.com/workshop/filedetails/?id=1103027918)
- [Arcanian](https://steamcommunity.com/sharedfiles/filedetails/?id=2359135864)
- [Shoggoth (Shoggoth & Friends Beta)](https://github.com/tydapo1/Shoggoths-Stuff-Rework)
- [Mindflayer (Shoggoth & Friends Beta)](https://github.com/tydapo1/Shoggoths-Stuff-Rework)
- [Nightgaunt (Shoggoth & Friends Beta)](https://github.com/tydapo1/Shoggoths-Stuff-Rework)
- [NostOS](https://steamcommunity.com/workshop/filedetails/?id=2740791476)
- [Kitsune](https://steamcommunity.com/workshop/filedetails/?id=1396610566)
- [Halfsea](https://steamcommunity.com/workshop/filedetails/?id=1396610566)
- [Argonian](https://steamcommunity.com/workshop/filedetails/?id=740694177)
- [Angel](https://steamcommunity.com/workshop/filedetails/?id=1686520464)
- [Goblin](https://steamcommunity.com/sharedfiles/filedetails/?id=2925162796)
- [Oni](https://steamcommunity.com/sharedfiles/filedetails/?id=2978143703)
- [Merling](https://steamcommunity.com/sharedfiles/filedetails/?id=3287386033)
- [Sharkling](https://steamcommunity.com/sharedfiles/filedetails/?id=3287386033)
- [Springeonton](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Brokenton](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Kanashimi](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Deerclops](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Void Glitches](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Nightmares](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Healon](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Narfin](https://steamcommunity.com/sharedfiles/filedetails/?id=2865339320)
- [Fennix](https://steamcommunity.com/sharedfiles/filedetails/?id=3194891396)
- [Eevee](https://steamcommunity.com/sharedfiles/filedetails/?id=3194891396)
- [Glaceon](https://steamcommunity.com/sharedfiles/filedetails/?id=2012704863)
- [Vaporeon](https://steamcommunity.com/sharedfiles/filedetails/?id=3283738255)
- [Sylveon](https://steamcommunity.com/sharedfiles/filedetails/?id=2843385916)
- [Lucario](https://steamcommunity.com/sharedfiles/filedetails/?id=1356955138)
- [Zoroark](https://steamcommunity.com/sharedfiles/filedetails/?id=2811625141)
- [Hisuian Zoroark](https://steamcommunity.com/sharedfiles/filedetails/?id=2813977483)
- [Felin](https://steamcommunity.com/sharedfiles/filedetails/?id=729429063)
- [Offworlder](https://steamcommunity.com/sharedfiles/filedetails/?id=1380631785)
- [Dark Latex](https://steamcommunity.com/sharedfiles/filedetails/?id=1818502101)
- [Troll](https://steamcommunity.com/sharedfiles/filedetails/?id=1301907771)
