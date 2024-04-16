local socket = require("socket")
if (get_application_name() == "PacketShare") then
    debug_print("PacketShare window detected. Minimizing...")
    socket.sleep(25)
    minimize();
end
