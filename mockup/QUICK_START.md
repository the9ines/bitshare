# 🚀 Quick Start Guide - bitshare App Mockup

## Option 1: Simple Python Server (Recommended)

1. **Open Terminal**
2. **Navigate to the mockup folder:**
   ```bash
   cd /Users/oberfelder/Desktop/the9ines.com/bitshare/mockup
   ```
3. **Start the server:**
   ```bash
   python3 -m http.server 8000
   ```
4. **Open your browser:** http://localhost:8000

## Option 2: Run the Auto-Launcher

1. **Open Terminal**
2. **Make the script executable:**
   ```bash
   chmod +x /Users/oberfelder/Desktop/the9ines.com/bitshare/mockup/start-server.sh
   ```
3. **Run the launcher:**
   ```bash
   ./start-server.sh
   ```

## Option 3: Direct File Access

If servers don't work, you can open the file directly:

1. **Open Finder**
2. **Navigate to:** `/Users/oberfelder/Desktop/the9ines.com/bitshare/mockup/`
3. **Double-click:** `index.html`

(Note: Some features may be limited when opened directly)

## Option 4: Alternative Servers

### Node.js (if installed):
```bash
cd /Users/oberfelder/Desktop/the9ines.com/bitshare/mockup
npx http-server -p 8000
```

### PHP (if installed):
```bash
cd /Users/oberfelder/Desktop/the9ines.com/bitshare/mockup
php -S localhost:8000
```

### VS Code Live Server:
1. Open VS Code
2. Install "Live Server" extension
3. Open the mockup folder
4. Right-click `index.html` → "Open with Live Server"

## Troubleshooting

### Port Already in Use?
Try a different port:
```bash
python3 -m http.server 8001
# or
python3 -m http.server 8080
```

### Python Not Found?
Try without the "3":
```bash
python -m http.server 8000
```

### Check What's Running on Port 8000:
```bash
lsof -i :8000
```

### Kill Process on Port 8000:
```bash
lsof -ti:8000 | xargs kill
```

## 🎯 What You'll See

Once running, the mockup includes:

- **🔐 Noise Protocol Security**: Encryption indicators and session status
- **📁 File Transfer Demo**: Drag & drop with realistic progress bars
- **🚀 Transport Switching**: Bluetooth ↔ WiFi Direct comparison
- **👥 Peer Management**: Live connection status simulation
- **🔧 Debug Console**: Real-time system messages (Cmd/Ctrl+K)
- **⚙️ Settings Panel**: Transport configuration (gear icon)

## 📱 Demo Controls

- **Drag files** to the drop zone
- **Press Cmd/Ctrl+K** for debug console
- **Click gear icon** for settings
- **Switch transport modes** at the bottom
- **Mobile gestures**: Swipe left for settings, swipe up for console

## 🆘 Still Having Issues?

1. **Check the files exist:**
   ```bash
   ls -la /Users/oberfelder/Desktop/the9ines.com/bitshare/mockup/
   ```

2. **Verify Python installation:**
   ```bash
   python3 --version
   ```

3. **Try the simple server script:**
   ```bash
   python3 /Users/oberfelder/Desktop/the9ines.com/bitshare/mockup/simple-server.py
   ```

4. **Open the help file:**
   Open `run-server.html` in your browser for more options

---

**Need more help?** Check the full `README.md` file for detailed documentation.