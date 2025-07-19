#!/usr/bin/env python3
"""
Simple HTTP server for the bitshare app mockup
Serves the web app locally for testing and demonstration
"""

import http.server
import socketserver
import webbrowser
import os
import sys
from pathlib import Path

class BitShareHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=Path(__file__).parent, **kwargs)
    
    def end_headers(self):
        # Add security headers
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        super().end_headers()
    
    def do_GET(self):
        # Serve index.html for root requests
        if self.path == '/':
            self.path = '/index.html'
        
        # Handle 404s gracefully
        if not os.path.exists(self.path.lstrip('/')):
            self.send_error(404, "File not found")
            return
            
        super().do_GET()
    
    def log_message(self, format, *args):
        # Custom logging format
        print(f"[{self.log_date_time_string()}] {format % args}")

def main():
    PORT = 8000
    
    # Check if port is already in use
    try:
        with socketserver.TCPServer(("", PORT), BitShareHandler) as httpd:
            print(f"🚀 bitshare mockup server starting...")
            print(f"📡 Server running at: http://localhost:{PORT}")
            print(f"🌐 Open in browser: http://localhost:{PORT}")
            print(f"🔧 Press Ctrl+C to stop the server")
            print()
            print("Features:")
            print("• Terminal-style interface with green theme")
            print("• Drag & drop file transfer simulation")
            print("• Noise Protocol security indicators")
            print("• Transport switching (Bluetooth ↔ WiFi Direct)")
            print("• Real-time peer connections")
            print("• Interactive debug console")
            print()
            
            # Try to open browser automatically
            try:
                webbrowser.open(f'http://localhost:{PORT}')
                print("✅ Browser opened automatically")
            except:
                print("⚠️  Please manually open http://localhost:8000 in your browser")
            
            print()
            print("🎯 Demo Instructions:")
            print("• Click or drag files to the drop zone")
            print("• Watch real-time file transfer progress")
            print("• Switch between transport modes")
            print("• Open settings panel (gear icon)")
            print("• Toggle debug console (Cmd/Ctrl+K)")
            print("• View peer connections at bottom")
            print()
            
            # Start server
            httpd.serve_forever()
            
    except OSError as e:
        if e.errno == 48:  # Port already in use
            print(f"❌ Port {PORT} is already in use")
            print(f"💡 Try: lsof -ti:{PORT} | xargs kill")
            print(f"   Or use a different port: python server.py --port XXXX")
        else:
            print(f"❌ Error starting server: {e}")
        sys.exit(1)
    
    except KeyboardInterrupt:
        print("\n🛑 Server stopped")
        sys.exit(0)

if __name__ == "__main__":
    main()