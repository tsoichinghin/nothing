import psutil
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

def check_remmina_rdp_connection(remote_ip):
    for proc in psutil.process_iter(['pid', 'name']):
        if proc.info['name'] == 'remmina':
            remmina_pid = proc.info['pid']
            break
    else:
        return False
    
    connections = psutil.net_connections(kind='inet')
    for conn in connections:
        if conn.pid == remmina_pid and conn.raddr and conn.raddr.ip == remote_ip and conn.status == 'ESTABLISHED':
            return True
    return False


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/rdp':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            rdp_status = check_remmina_rdp_connection()
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
    start_server()
