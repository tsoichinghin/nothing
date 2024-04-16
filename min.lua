if (get_application_name() == "PacketShare") or (get_window_name() == "PacketShare") or (get_window_name() == "Wine System Tray") then
    debug_print("Lua said：PacketShare window detected. Minimizing...")
    minimize();
end
