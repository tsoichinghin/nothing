debug_print("Checking window: " .. get_window_name())

if (get_application_name() == "PacketShare") then
    debug_print("PacketShare window detected. Minimizing...")
    minimize();
end
