# bitshare App Mockup

A realistic web-based mockup of the bitshare decentralized file sharing application with Noise Protocol encryption and multi-transport support.

## Features

### 🔐 Security
- **Noise Protocol**: End-to-end encryption with forward secrecy
- **Session Management**: Automatic 60-second rekey intervals
- **Peer Authentication**: SHA256 fingerprint verification
- **Rate Limiting**: DDoS protection and security measures

### 🚀 Transport Layer
- **Bluetooth LE**: Mesh networking with Noise encryption
- **WiFi Direct**: High-speed transfers (15x faster)
- **Intelligent Routing**: Automatic transport selection
- **Battery Optimization**: Power-aware transport switching

### 💻 User Interface
- **Terminal Theme**: Green-on-black aesthetic matching bitchat
- **Drag & Drop**: Intuitive file transfer interface
- **Real-time Progress**: Live transfer status and speeds
- **Responsive Design**: Mobile-optimized with touch gestures

### 📱 Interactive Demo
- **File Transfer Simulation**: Realistic progress bars and speeds
- **Peer Management**: Live connection status and discovery
- **Debug Console**: Real-time system messages and logs
- **Settings Panel**: Transport configuration and security status

## Quick Start

1. **Start the server:**
   ```bash
   python3 server.py
   ```

2. **Open in browser:**
   - Automatically opens at `http://localhost:8000`
   - Or manually navigate to the URL

3. **Try the demo:**
   - Drag files to the drop zone
   - Watch transfer progress
   - Switch transport modes
   - Open debug console (Cmd/Ctrl+K)

## File Structure

```
mockup/
├── index.html          # Main app interface
├── style.css           # Terminal-style CSS
├── script.js           # Interactive JavaScript
├── server.py           # Local development server
├── README.md           # This file
└── favicon.ico         # App icon
```

## Technical Implementation

### HTML Structure
- **Header**: App title, transport status, actions
- **Drop Zone**: File drag & drop with visual feedback
- **Transfers**: Real-time progress bars and status
- **Peers**: Connected device list with signal strength
- **Sidebar**: Settings and configuration panel
- **Console**: Debug output and system messages

### CSS Styling
- **CSS Variables**: Theme-based color system
- **Responsive Design**: Mobile-first approach
- **Animations**: Smooth transitions and loading states
- **Typography**: Monospace fonts for terminal feel

### JavaScript Features
- **File Processing**: Drag & drop and file selection
- **Transport Simulation**: Realistic speed calculations
- **Progress Animation**: Smooth progress bar updates
- **Peer Management**: Connection status simulation
- **Console Logging**: Real-time debug messages

## Keyboard Shortcuts

- **Cmd/Ctrl+K**: Toggle debug console
- **Cmd/Ctrl+,**: Open settings sidebar
- **Cmd/Ctrl+H**: Show transfer history

## Touch Gestures

- **Swipe Left**: Open settings sidebar
- **Swipe Up**: Open debug console

## Demo Scenarios

The mockup includes several built-in demonstrations:

1. **Auto Demo**: Automatically starts file transfers after 2 seconds
2. **Transport Switching**: Shows WiFi Direct speed advantages
3. **Peer Activity**: Simulates connection/disconnection events
4. **Background Tasks**: Periodic security and maintenance operations

## Compatibility

- **Modern Browsers**: Chrome, Firefox, Safari, Edge
- **Mobile Devices**: iOS Safari, Android Chrome
- **Desktop**: macOS, Windows, Linux
- **Responsive**: Adapts to all screen sizes

## Security Notes

This is a **demonstration mockup** only:
- No actual files are transferred
- No real network connections are made
- All data is simulated and local
- Security features are for visual demonstration

## Related Projects

- **bitchat**: Original iOS app by Jack Dorsey
- **bitshare**: Enhanced version with WiFi Direct support
- **Noise Protocol**: Cryptographic framework specification

## License

Public Domain - Free and unencumbered software released into the public domain.

---

*Built with vanilla HTML, CSS, and JavaScript - no frameworks required*