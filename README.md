# Aux Send Router

![Aux_Send_Router_Opening_Window](https://github.com/GhostsonAcid/Aux_Send_Router/blob/main/Images/Aux_Send_Router_Opening_Window.png)

Aux Send Router is a relatively simple Lua Script for the Ardour DAW (8.12+) that allows one to add Aux Sends from one or many selected tracks and buses to a bus of your choosing.

### Features:

- Select from all available *existing* buses in the session.
- You can also create a *new* bus and route to the new one.
- Prevents self-routing/feedback situations.
- Conveniently set the send level (in dB) you want to use for any new Aux Sends created.
- Automatically saves the session just before Aux Send creation, just in case something goes wrong.

### Limitations:

- Only works with *audio* tracks and buses... for now.

--------------------------------------------------

### Other notes:

**Aux Send Router** is partially based on (and motivated by) the ["Send Tracks to Bus" Lua script](https://github.com/Ardour/ardour/blob/master/share/scripts/send_to_bus.lua) by Robin Gareus (x42)! *~Thanks, Robin!*

And if you're interested in getting into Lua scripting for Ardour, [this trove of examples](https://github.com/Ardour/ardour/tree/master/share/scripts) is absolutely essential!

--------------------------------------------------

_~Enjoy!_

_J. K. Lookinland_
