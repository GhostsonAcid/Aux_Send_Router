# Aux Send Router

## Basic Description

**Aux Send Router** is a relatively simple Lua Script for the Ardour DAW (8.12+) that allows one to add Aux Sends from one or more selected audio tracks and buses to a bus of your choosing.

![Aux_Send_Router_Opening_Window](https://github.com/GhostsonAcid/Aux_Send_Router/blob/main/Images/Aux_Send_Router_Opening_Window.png)

### Features:

- Select from all available *existing* buses in the session.
- You can also create a *new* bus and route to the new one.
- Prevents self-routing/feedback situations.
- Conveniently set the send level (in dB) you want to use for any new Aux Sends created.
- Automatically saves the session just before Aux Send creation, just in case something goes wrong.

### Limitations:

- Only works with *audio* tracks and buses... for now.

--------------------------------------------------

## Installation

Simply click here to download the Aux_Send_Router.lua (v1.0) file (link coming soon), and then do the following based on your OS:

### GNU/Linux:

1. Navigate to the $HOME/.config/ardour8 **(or ardour9)** /scripts folder.
2. Place Aux_Send_Router.lua in that scripts folder.
3. _(continues below...)_

### macOS/Mac OS X:

1. Open a Finder window, press cmd-shift-G, and type-in: ~/Library/Preferences/Ardour8 **(or Ardour9)** /scripts/
2. Place Aux_Send_Router.lua in that scripts folder.
3. _(continues below...)_

### Windows:

1. Navigate to the %localappdata%\ardour8 **(or ardour9)** \scripts folder. 
2. Place Aux_Send_Router.lua in that scripts folder.
3. _(continues below...)_

### _Continued steps for all systems:_

3. Open Ardour and go to _Edit → Lua Scripts → Script Manager._
4. Select an "Action" (e.g. "Action 1", etc.) that is "Unset", then click "Add/Set" at the bottom-left.
5. Click "Refresh", and then find and select **Aux Send Router** in the "Shortcut" drop-down menu.
6. Click "Add" and then close the Script Manager window.
7. **Aux Send Router** now exists as an easy-access button in the top-right of the DAW (-look for the letters "AUX").

> [!TIP]
> You can always just click any empty shortcut button in the top-right, hit "Refresh", and then find and set **Aux Send Router** from the dropdown menu!  Also, to remove a shortcut from a button, hold shift and then right-click it.

--------------------------------------------------

## Additional notes:

**Aux Send Router** is partially based on (and motivated by) the modest/light ["Send Tracks to Bus" Lua script](https://github.com/Ardour/ardour/blob/master/share/scripts/send_to_bus.lua) by Robin Gareus (x42) that is included with Ardour 9. *~Thanks, Robin!*

If you're interested in getting into Lua scripting for Ardour, [this trove of examples](https://github.com/Ardour/ardour/tree/master/share/scripts) is absolutely essential(!), as well as the [Lua Bindings Class Reference](https://manual.ardour.org/lua-scripting/class_reference/) list.

--------------------------------------------------

_~Enjoy!_

_J. K. Lookinland_
