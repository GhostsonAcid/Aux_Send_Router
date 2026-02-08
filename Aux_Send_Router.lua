ardour {
  ["type"] = "EditorAction",
  name = "Aux Send Router",
  license = "GPL",
  author = "Joseph K. Lookinland",
  description = [[       Aux Send Router allows you to add Aux Sends to/from
  one or more selected tracks/buses to a track/bus of your
  choosing, including a new one. You can also set the level
  (dB) for any created Aux Send(s). (v1.0)]]
}

function factory () return function ()

  -------------- Step 1: Collect Selected Tracks/Buses --------------

  local sel = Editor:get_selection ()
  local routes = ARDOUR.RouteListPtr ()
  local single_route_selected = false -- Will use later for final popup creation.
  local master_bus_selected = false
  local midi_route_used = false -- Used for special reminder text in final popup.

  for r in sel.tracks:routelist():iter() do
    if r ~= Session:master_out() and (r:n_outputs():n_audio() > 0 or r:n_outputs():n_midi() > 0) then -- Including the Master bus is apparently not allowed in Ardour, and
      routes:push_back(r)                                                                             -- attempting later to add an Aux Send to the Master bus will crash it.     
      if r:n_outputs():n_midi() > 0 then
        midi_route_used = true
      end
    elseif r == Session:master_out() then
      master_bus_selected = true
    end
  end

  if master_bus_selected then -- Include a unique popup if the Master bus is selected...
    LuaDialog.Message(
      "Master Bus Selected!",
      "The Master Bus cannot have an Aux Send added to it!",
      LuaDialog.MessageType.Warning,
      LuaDialog.ButtonType.Close
    ):run()
    return
  end

  if routes:size() == 0 then
    LuaDialog.Message(
      "No Routes Selected!",
      "Please select one or more tracks/buses.",
      LuaDialog.MessageType.Warning,
      LuaDialog.ButtonType.Close
    ):run()
    return
  end

  if routes:size() == 1 then -- Used later for final popup...
    single_route_selected = true
  end

  -------------- Step 2: Build Table of Selected Routes --------------

  local selected_names = {}
  for r in routes:iter() do
    selected_names[r:name()] = true
  end

  -------------- Step 3: Create Initial Popup --------------

  local dialog = LuaDialog.Dialog(
    "Aux Send Router (v1.0)",
    {
      { type = "heading", title = "What routing would you like to achieve?" },
      { type = "dropdown",
        key = "routing_direction",
        title = "Routing Options",
        values = {
          ["Option 1 - Route the current selection to a bus...                "] = "route_to_bus", -- Spaces added to make dd-menu wider to accommodate Option 2.
          ["Option 2 - Route from a track/bus to the current selection..."] = "route_from_track_or_bus"
        },
      }
    }
  )

  local popup1_result = dialog:run()
  if not popup1_result then return end -- Safeguard; not really necessary(?).

  -------------- Step 4: Check if Ardour won't be able to make the Connection(s) --------------

  if popup1_result["routing_direction"] == "route_from_track_or_bus" then

    for r in routes:iter() do
      local t = r:to_track()

      if not t:isnil() then -- Indicates that this particular route is a *track*; not allowed in this case!

        LuaDialog.Message(
          "Track(s) Selected!",
          "Ardour cannot route an Aux Send to a track!\n\nPlease select ONLY buses for this action.",
          LuaDialog.MessageType.Warning,
          LuaDialog.ButtonType.Close
        ):run()
        return

      end
    end
  end

  -------------- Step 5. Gather Necessary Routes for Dropdown Menu, as Required --------------

  local route_values = {}
  local route_map = {}

  for r in Session:get_routes():iter() do -- Do for either routing option chosen...
    local t = r:to_track()

    if t:isnil() -- Indicates that this particular route is a *bus* (not a track); collect buses for *either* selected option...
      and r ~= Session:master_out() -- Again, don't include the Master bus.
      and (r:n_outputs():n_audio() > 0 or r:n_outputs():n_midi() > 0) -- Includes midi buses.
      and not selected_names[r:name()] -- Prevents self-routing/feedback scenarios. (-Which Ardour does NOT block if you make an Aux Send via a script like this! :O)
    then                                                                                                               -- Will probably inform Robin (x42) about this...
      local name = r:name()
      route_values[name] = name -- Add appropriate bus-name to table used for dd-menu.
      route_map[name] = r
    end

    if popup1_result["routing_direction"] == "route_from_track_or_bus" then -- Add tracks as well, but ONLY for this option...
      if not t:isnil() -- Is a *track*.
      and (r:n_outputs():n_audio() > 0 or r:n_outputs():n_midi() > 0) -- Includes midi tracks.
      and not selected_names[r:name()] -- Prevents self-routing/feedback scenarios.
      then
        local name = r:name()
        route_values[name] = name -- Add appropriate bus-name to table used for dd-menu.
        route_map[name] = r
      end
    end
  end

  -- Add options for creating a new track and/or bus:
  route_values["--- Create New Audio Bus ---"] = "new_audio_bus" -- Due to the inclusion of "---" at the beginning, this will be shown as the topmost/'default' setting (~99% of the time).
  route_values["--- Create New Midi Bus ---"] = "new_midi_bus"

  if popup1_result["routing_direction"] == "route_from_track_or_bus" then
    route_values["--- Create New Audio Track ---"] = "new_audio_track"
    route_values["--- Create New Midi Track ---"] = "new_midi_track"
  end

  -------------- Step 6. Create Secondary Popup, as Required --------------

  local popup2_result

  if popup1_result["routing_direction"] == "route_to_bus" then

    local dialog = LuaDialog.Dialog(
      "Aux Send Router (v1.0)",
      {
        { type = "heading", title = "Please choose the bus you want to route to:" },
        { type = "dropdown",
          key = "route_choice",
          title = "Available Routes",
          values = route_values
        },
        { type = "fader",
          key = "gain",
          title = "Aux Send Level",
          default = 0 -- 0 dB
        }
      }
    )

    popup2_result = dialog:run()

  elseif popup1_result["routing_direction"] == "route_from_track_or_bus" then -- Being verbose here... : P

    local dialog = LuaDialog.Dialog(
      "Aux Send Router (v1.0)",
      {
        { type = "heading", title = "Please choose the track or bus you want to route from:" },
        { type = "dropdown",
          key = "route_choice",
          title = "Available Routes",
          values = route_values
        },
        { type = "fader",
          key = "gain",
          title = "Aux Send Level",
          default = 0 -- 0 dB
        }
      }
    )

    popup2_result = dialog:run()

  end

  if not popup2_result then return end

  -------------- Step 7. Save the session --------------

  Session:save_state("", false, false, false, false, false) -- Precautionary; Just in case something goes wrong and Ardour crashes somehow.

  -------------- Step 8. Establish the Selected Track or Bus --------------

  local destination_route

  if popup2_result["route_choice"] == "new_audio_bus" then -- Create a new audio bus, if required (~following some of Robin's logic here)...

    local chn = 2
    local mst = Session:master_out()
    if not mst:isnil() then
      chn = mst:n_inputs():n_audio()
    end
    if chn == 0 then chn = 2 end

    local create_audio_bus = Session:new_audio_route(
      chn, chn,
      ARDOUR.RouteGroup(),
      1, "",
      ARDOUR.PresentationInfo.Flag.AudioBus,
      ARDOUR.PresentationInfo.max_order
    )

    destination_route = create_audio_bus:front()

  elseif popup2_result["route_choice"] == "new_audio_track" then -- Create a new audio track, if required...

    local chn = 2
    local mst = Session:master_out()
    if not mst:isnil() then
      chn = mst:n_inputs():n_audio()
    end
    if chn == 0 then chn = 2 end

    local create_audio_track = Session:new_audio_track(
      chn, chn,
      ARDOUR.RouteGroup(),
      1, "",
      ARDOUR.PresentationInfo.max_order,
      ARDOUR.TrackMode.Normal
    )

    destination_route = create_audio_track:front()

  elseif popup2_result["route_choice"] == "new_midi_bus" then -- Create a new midi bus, if required...

    local create_midi_bus = Session:new_midi_route(
      ARDOUR.RouteGroup(),
      1,
      "",
      false,
      ARDOUR.PluginInfo(),
      ARDOUR.PresetRecord(),
      ARDOUR.PresentationInfo.Flag.MidiBus,
      ARDOUR.PresentationInfo.max_order
    )
    
    destination_route = create_midi_bus:front()

  elseif popup2_result["route_choice"] == "new_midi_track" then -- Create a new midi track, if required... 
  
    local create_midi_track = Session:new_midi_track(
      ARDOUR.ChanCount(ARDOUR.DataType.midi(), 1),
      ARDOUR.ChanCount(ARDOUR.DataType.midi(), 1),
      false,
      ARDOUR.PluginInfo(),
      ARDOUR.PresetRecord(),
      ARDOUR.RouteGroup(),
      1,
      "",
      ARDOUR.PresentationInfo.max_order,
      ARDOUR.TrackMode.Normal,
      false,
      false
    )
    
    destination_route = create_midi_track:front()

  else
    destination_route = route_map[popup2_result["route_choice"]] -- Establish the specific, already-existing, chosen track or bus to use.
  end

  if not destination_route then -- Something went wrong; not really necessary(?).
    LuaDialog.Message(
      "Error!",
      "The chosen bus was somehow not resolved... O___o",
      LuaDialog.MessageType.Error,
      LuaDialog.ButtonType.Close
    ):run()
    return
  end

  -------------- Step 9. Convert Aux Send 'Fader' dB to 0-to-1 Value --------------

  local gain_db = popup2_result["gain"]
  local linear_gain = 10 ^ (gain_db / 20)

  -------------- Step 10. Add Aux Sends --------------

  local created_count = 0 -- Counter to count created (i.e. new) Aux Sends.
  local existing_count = 0 -- Counter to count existing Aux Sends.

  if popup1_result["routing_direction"] == "route_to_bus" then

    for r in routes:iter() do

      local before = 0 -- Count sends BEFORE attempting to add a new Aux Send...
      while true do
        local s = r:nth_send(before)
        if s:isnil() then break end
        before = before + 1
      end

      r:add_aux_send(destination_route, r:main_outs()) -- Attempt* to add Aux Send (*one to the chosen bus might already exist).

      local after = 0 -- Count sends AFTER attempting to add a new Aux Send...
      while true do
        local s = r:nth_send(after)
        if s:isnil() then break end
        after = after + 1
      end

      if after > before then -- Did Ardour actually create a new send? ...
        created_count = created_count + 1 -- If so, then add to the right counter.

        local lvl = r:send_level_controllable(before, false)
        if not lvl:isnil() then
          lvl:set_value(linear_gain, 1.0) -- Set the gain of the Aux Send, using the appropriately-converted "linear_gain" value.
        end
      else
        existing_count = existing_count + 1 -- If not, then add to the other counter.
      end
    end

  elseif popup1_result["routing_direction"] == "route_from_track_or_bus" then

    -- First do some name sorting, for convenience:
    local route_array = {}

    for r in routes:iter() do
      table.insert(route_array, r)
    end

    table.sort(route_array, function(a, b)
      return a:name():lower() < b:name():lower()
    end)

    local source = destination_route  -- Name-swap; the chosen track or bus we route FROM.
  
    for _, target in ipairs(route_array) do -- Again, should only be a *bus or buses* at this point...

      local before = 0 -- Count sends before.
      while true do
        local s = source:nth_send(before)
        if s:isnil() then break end
        before = before + 1
      end
  
      source:add_aux_send(target, source:main_outs())
  
      local after = 0 -- Count sends after.
      while true do
        local s = source:nth_send(after)
        if s:isnil() then break end
        after = after + 1
      end
  
      if after > before then
        created_count = created_count + 1
  
        local lvl = source:send_level_controllable(before, false)
        if not lvl:isnil() then
          lvl:set_value(linear_gain, 1.0)
        end
      else
        existing_count = existing_count + 1
      end
    end
  end

  -------------- Step 11. Present Final, Conditional Popup --------------

  if popup2_result["route_choice"] == "new_midi_track" or popup2_result["route_choice"] == "new_midi_bus" then
    midi_route_used = true
  end

  if destination_route:n_outputs():n_midi() > 0 then
    midi_route_used = true
  end

  midi_suffix = "" -- Keep midi_suffix blank/empty, initially.

  if midi_route_used then -- Create specific text used in the final popup, only for situations involving midi...
    midi_suffix =
      "\n\nNOTE: For MIDI tracks and buses, you may need to add additional audio ports to allow audio to pass through.  " ..
      "To do this, you can Left-click on the \"INPUT\" portion of a MIDI track or bus (near the top of its mixer strip), " ..
      "and use the \"Add audio port\" function."
  end

  if single_route_selected then -- Check if single track/bus is/was selected.

    if created_count == 0 then -- Check if no Aux Send was created.

      if popup1_result["routing_direction"] == "route_from_track_or_bus" then -- Check if "Option 2" had been selected in Popup 1.
        LuaDialog.Message(
          "No Aux Send is needed!",
          string.format(
            "The selected bus is already receiving an Aux Send from %s!\n%s",
            destination_route:name(),
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      else
        LuaDialog.Message(
          "No Aux Send is needed!",
          string.format(
            "The selected route already has an Aux Send to %s!\n%s",
            destination_route:name(),
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      end

    else -- Aux Send WAS created.

      if popup1_result["routing_direction"] == "route_from_track_or_bus" then
        LuaDialog.Message(
          "Success!",
          string.format(
            "The selected bus is now receiving an Aux Send from %s!\n%s",
            destination_route:name(),
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      else
        LuaDialog.Message(
          "Success!",
          string.format(
            "The selected route now has an Aux Send to %s!\n%s",
            destination_route:name(),
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      end

    end

  else -- If more than one route is/was selected.

    if created_count == 0 then

      if popup1_result["routing_direction"] == "route_from_track_or_bus" then
        LuaDialog.Message(
          "No Aux Sends are needed!",
          string.format(
            "All of the selected buses are already receiving an Aux Send from %s!\n%s",
            destination_route:name(),
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      else
        LuaDialog.Message(
          "No Aux Sends are needed!",
          string.format(
            "All of the selected routes already have an Aux Send to %s!\n%s",
            destination_route:name(),
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      end

    else -- At least one new Aux Send was created.

      if popup1_result["routing_direction"] == "route_from_track_or_bus" then
        LuaDialog.Message(
          "Success!",
          string.format(
            "All of the selected buses are now receiving an Aux Send from %s!\n\n\n• New Aux Send(s) created: %d\n\n• Aux Send(s) that already existed: %d\n%s",
            destination_route:name(),
            created_count,
            existing_count,
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      else
        LuaDialog.Message(
          "Success!",
          string.format(
            "All of the selected tracks/buses now have an Aux Send to %s!\n\n\n• New Aux Send(s) created: %d\n\n• Aux Send(s) that already existed: %d\n%s",
            destination_route:name(),
            created_count,
            existing_count,
            midi_suffix
          ),
          LuaDialog.MessageType.Info,
          LuaDialog.ButtonType.Close
        ):run()
      end

    end

  end

end end

-- BONUS; Manifest a button icon ("AUX"); also based on an example from Robin:
function icon (params) return function (ctx, width, height, fg)
	local txt = Cairo.PangoLayout (ctx, "ArdourMono ".. math.floor(math.min(width, height) * 0.43) .. "px")
	txt:set_text("AUX")
	local tw, th = txt:get_pixel_size ()
	ctx:move_to (.5 * (width - tw), .5 * (height - th))
	ctx:set_source_rgba (ARDOUR.LuaAPI.color_to_rgba (fg))
	txt:show_in_cairo_context (ctx)
end end