#!/usr/bin/env python3
"""
Simple HTTP server for bitshare mockup
"""
import http.server
import socketserver
import webbrowser
import os
import sys

def start_server():
    PORT = 8000
    
    # Change to the directory containing the files
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    # Try different ports if 8000 is occupied
    for port in range(8000, 8010):
        try:
            with socketserver.TCPServer(("", port), http.server.SimpleHTTPRequestHandler) as httpd:
                print(f"🚀 bitshare mockup server running at: http://localhost:{port}")
                print(f"📱 Open this URL in your browser: http://localhost:{port}")
                print(f"🔧 Press Ctrl+C to stop")
                
                # Try to open browser
                try:
                    webbrowser.open(f'http://localhost:{port}')
                except:
                    pass
                
                httpd.serve_forever()
        except OSError:
            continue
    
    print("❌ No available ports found")
    sys.exit(1)

if __name__ == "__main__":
    try:
        start_server()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped")
        sys.exit(0)