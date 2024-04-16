function on_window_open(event)
    if (get_application_name() == "PacketShare") or (get_window_name() == "PacketShare") or (get_window_name() == "Wine System Tray") then
        debug_print("PacketShare window detected. Minimizing...")
        minimize();
    end
end

add_signal_handler("window_open", on_window_open)
