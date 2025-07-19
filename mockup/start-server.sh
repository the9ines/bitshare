#!/bin/bash

# bitshare Mockup Server Launcher
# This script tries multiple methods to start a local server

echo "🚀 bitshare App Mockup - Starting Server..."
echo "================================================"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Function to check if a port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Find an available port
PORT=8000
while ! check_port $PORT && [ $PORT -lt 8010 ]; do
    PORT=$((PORT + 1))
done

if [ $PORT -ge 8010 ]; then
    echo "❌ No available ports found between 8000-8009"
    echo "💡 Try closing other servers or use a different port range"
    exit 1
fi

echo "🌐 Using port: $PORT"
echo "📱 URL: http://localhost:$PORT"
echo ""

# Try Python 3 first
if command -v python3 &> /dev/null; then
    echo "✅ Using Python 3"
    echo "🔧 Press Ctrl+C to stop the server"
    echo ""
    
    # Try to open browser
    if command -v open &> /dev/null; then
        sleep 2 && open "http://localhost:$PORT" &
    elif command -v xdg-open &> /dev/null; then
        sleep 2 && xdg-open "http://localhost:$PORT" &
    fi
    
    python3 -m http.server $PORT
    
# Try Python 2 as fallback
elif command -v python &> /dev/null; then
    echo "✅ Using Python 2"
    echo "🔧 Press Ctrl+C to stop the server"
    echo ""
    
    # Try to open browser
    if command -v open &> /dev/null; then
        sleep 2 && open "http://localhost:$PORT" &
    elif command -v xdg-open &> /dev/null; then
        sleep 2 && xdg-open "http://localhost:$PORT" &
    fi
    
    python -m SimpleHTTPServer $PORT
    
# Try Node.js
elif command -v node &> /dev/null; then
    echo "✅ Using Node.js"
    echo "🔧 Press Ctrl+C to stop the server"
    echo ""
    
    # Try to open browser
    if command -v open &> /dev/null; then
        sleep 2 && open "http://localhost:$PORT" &
    elif command -v xdg-open &> /dev/null; then
        sleep 2 && xdg-open "http://localhost:$PORT" &
    fi
    
    npx http-server -p $PORT
    
# Try PHP
elif command -v php &> /dev/null; then
    echo "✅ Using PHP"
    echo "🔧 Press Ctrl+C to stop the server"
    echo ""
    
    # Try to open browser
    if command -v open &> /dev/null; then
        sleep 2 && open "http://localhost:$PORT" &
    elif command -v xdg-open &> /dev/null; then
        sleep 2 && xdg-open "http://localhost:$PORT" &
    fi
    
    php -S localhost:$PORT
    
else
    echo "❌ No suitable server found"
    echo ""
    echo "Please install one of the following:"
    echo "• Python 3: brew install python3"
    echo "• Node.js: brew install node"
    echo "• PHP: brew install php"
    echo ""
    echo "Or open index.html directly in your browser"
    echo "(some features may be limited)"
    
    # Try to open the file directly
    if command -v open &> /dev/null; then
        echo "🌐 Opening index.html directly..."
        open "index.html"
    fi
    
    exit 1
fi

echo ""
echo "🛑 Server stopped"