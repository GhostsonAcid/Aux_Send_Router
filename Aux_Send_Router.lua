ardour {
  ["type"] = "EditorAction",
  name = "Aux Send Router",
  license = "GPL",
  author = "Joseph K. Lookinland",
  description = [[Add exactly one Aux Send from all selected tracks and buses to a chosen bus, including creating a new bus.  You can also set the level for the created Aux Send(s).]]
}

function factory () return function ()

  -------------- Step 1: Collect Selected Tracks/Buses --------------

  local sel = Editor:get_selection ()
  local routes = ARDOUR.RouteListPtr ()
  local single_route_selected = false -- Will use later for final popup creation.
  local master_bus_selected = false

  for r in sel.tracks:routelist():iter() do
    if r ~= Session:master_out() and r:n_outputs():n_audio() > 0 then -- Including the Master bus is apparently not allowed in Ardour, and
      routes:push_back(r)                                             -- attempting later to add an Aux Send to the Master bus will crash it.     
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

  if routes:size() == 1 then -- Check if only one route (track or bus) is currently selected; used later for final popup...
    single_route_selected = true
  end

  -------------- Step 2: Build Table of Selected Routes --------------

  local selected_names = {}
  for r in routes:iter() do
    selected_names[r:name()] = true
  end

  -------------- Step 3. Gather Buses for Dropdown Menu --------------

  local bus_values = {}
  local bus_map = {}

  bus_values["--- Create New Bus ---"] = "new" -- Due to the inclusion of "---" at the beginning, this will be shown as the topmost/'default' setting (~99% of the time).

  for r in Session:get_routes():iter() do
    local t = r:to_track()

    if t:isnil() -- Indicates that this particular route is a *bus* (not a track).
       and r ~= Session:master_out() -- Again, don't include the Master bus.
       and r:n_inputs():n_audio() > 0
       and not selected_names[r:name()] -- Prevents self-routing/feedback scenarios. (-Which Ardour does NOT block if you make an Aux Send via a script like this! :O)
    then                                                                                                                  -- Will probably inform Robin (x42) about this...
      local name = r:name()
      bus_values[name] = name -- Add appropriate bus-name to table used for dd-menu.
      bus_map[name] = r
    end
  end

  -------------- Step 4. Initiate Main Popup Window --------------

  local dialog = LuaDialog.Dialog(
    "Aux Send Router (v1.0)",
    {
      { type = "heading", title = "Please select the bus you want to route to:" },
      {
        type = "dropdown",
        key = "bus",
        title = "Destination Bus",
        values = bus_values
      },
      {
        type = "fader",
        key = "gain",
        title = "Aux Send Level",
        default = 0 -- dB
      }
    }
  )

  local dialog_result = dialog:run()
  if not dialog_result then return end -- Safeguard; not really necessary.

  -------------- Step 5. Save the session --------------

  Session:save_state("", false, false, false, false, false) -- Precautionary; Just in case something goes wrong and Ardour crashes somehow.

  -------------- Step 6. Establish the Selected Bus --------------

  local destination_bus

  if dialog_result["bus"] == "new" then -- Create (and ultimately route) to a new bus if that's what the user wants...
    local chn = 2                                                            -- Following some of Robin's logic here...
    local mst = Session:master_out()
    if not mst:isnil() then
      chn = mst:n_inputs():n_audio()
    end
    if chn == 0 then chn = 2 end

    local new_bus = Session:new_audio_route(
      chn, chn,
      ARDOUR.RouteGroup(),
      1, "",
      ARDOUR.PresentationInfo.Flag.AudioBus,
      ARDOUR.PresentationInfo.max_order
    )

    destination_bus = new_bus:front()
  else
    destination_bus = bus_map[dialog_result["bus"]] -- Establish the specific, already-existing bus to use.
  end

  if not destination_bus then -- Something went wrong; not really necessary(?).
    LuaDialog.Message(
      "Error!",
      "The chosen bus was somehow not resolved... O___o",
      LuaDialog.MessageType.Error,
      LuaDialog.ButtonType.Close
    ):run()
    return
  end

  -------------- Step 7. Convert Fader dB to 0-to-1 Value --------------

  local gain_db = dialog_result["gain"]
  local linear_gain = 10 ^ (gain_db / 20)

  -------------- Step 8. Add Aux Sends --------------

  local created_count = 0 -- Counter to count created (i.e. new) Aux Sends.
  local existing_count = 0 -- Counter to count existing Aux Sends.

  for r in routes:iter() do

    local before = 0 -- Count sends BEFORE attempting to add a new Aux Send...
    while true do
      local s = r:nth_send(before)
      if s:isnil() then break end
      before = before + 1
    end

    r:add_aux_send(destination_bus, r:main_outs()) -- Attempt* to add Aux Send (*one to the chosen bus might already exist)

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

  -------------- Step 9. Present Final Popup --------------

  if single_route_selected then -- Check if single track/bus is/was selected...

    if created_count == 0 then -- Check if no Aux Sends were added...
      LuaDialog.Message(
        "No Aux Send is needed!",
        string.format(
          "The selected route already has an Aux Send to %s!\n",
          destination_bus:name()
        ),
        LuaDialog.MessageType.Info,
        LuaDialog.ButtonType.Close
      ):run()
    else
      LuaDialog.Message(
        "Success!",
        string.format(
          "The selected track or bus was successfully routed to %s!\n",
          destination_bus:name()
        ),
        LuaDialog.MessageType.Info,
        LuaDialog.ButtonType.Close
      ):run()
    end
      
  else -- If more than one route is/was selected...

    if created_count == 0 then -- Did all already have an Aux Send to the chosen bus? ...
        LuaDialog.Message(
        "No Aux Sends are needed!",
        string.format(
          "All of the selected tracks/buses already have an Aux Send to %s!\n",
          destination_bus:name()
        ),
        LuaDialog.MessageType.Info,
        LuaDialog.ButtonType.Close
      ):run()
    else
      LuaDialog.Message(
        "Success!",
        string.format(
          "All of the selected tracks/buses now have Aux Sends to %s!\n\n\nNew Aux Send(s) created: %d\n\nAux Send(s) that already existed: %d\n",
          destination_bus:name(),
          created_count,
          existing_count
        ),
        LuaDialog.MessageType.Info,
        LuaDialog.ButtonType.Close
      ):run()
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