import psutil
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Thread

packetshare_status = False

def check_packetshare():
    global packetshare_status
    while True:
        packetshare_pid = None
        for proc in psutil.process_iter(['pid', 'name']):
            if proc.info['name'] == 'PacketShare.exe':
                packetshare_pid = proc.info['pid']
                break

        if packetshare_pid == None:
           packetshare_status = False
        
        time.sleep(5)

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/rdp':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(str(rdp_status).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

def start_server():
    server_address = ('', 3001)
    httpd = HTTPServer(server_address, RequestHandler)
    print('Starting server on port 3001...')
    httpd.serve_forever()

if __name__ == '__main__':
    thread = Thread(target=check_packetshare)
    thread.daemon = True
    thread.start()
    start_server()
