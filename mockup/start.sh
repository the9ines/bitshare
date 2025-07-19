#!/bin/bash

# bitshare App Mockup Launcher
# Start the local web server for the bitshare app demo

echo "🚀 Starting bitshare mockup server..."
echo "📱 Web-based demo of the bitshare decentralized file sharing app"
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "💡 Please install Python 3 and try again."
    exit 1
fi

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Navigate to the mockup directory
cd "$DIR"

# Start the server
echo "🌐 Starting server at http://localhost:8000"
echo "🔧 Press Ctrl+C to stop the server"
echo ""

python3 server.py

echo ""
echo "🛑 Server stopped"