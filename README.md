# bitshare

> **Secure Decentralized File Sharing Over Bluetooth Mesh Networks**

A privacy-first, decentralized file sharing application that works over Bluetooth mesh networks. No internet required, no servers, no accounts - just secure peer-to-peer file transfer.

## Attribution

bitshare is built upon the foundation of **bitchat** by [Jack Dorsey](https://github.com/jack) ([@jackjackbits](https://github.com/jackjackbits)). We extend our deep gratitude to Jack for creating the innovative mesh networking protocol and secure communication foundation that makes bitshare possible.

- **Original Project**: [bitchat](https://github.com/jackjackbits/bitchat) 
- **Original Author**: Jack Dorsey
- **bitshare Fork**: Adapted for secure file sharing use cases

## Project Purpose

bitshare transforms Jack Dorsey's secure mesh chat protocol into a powerful file sharing platform. While preserving all the privacy and security features of the original bitchat, bitshare extends the capability to:

- **Share Files Securely**: Transfer documents, images, and media over encrypted mesh networks
- **Work Offline**: No internet or cellular connection required - pure peer-to-peer communication
- **Maintain Privacy**: No servers, no tracking, no data collection - your files stay between you and your intended recipients
- **Scale Across Distance**: Multi-hop relay allows file sharing across extended ranges through mesh networking

## Key Features

### 🔒 **Privacy & Security** (Inherited from bitchat)
- **End-to-End Encryption**: X25519 key exchange + AES-256-GCM for all transfers
- **No Registration**: No accounts, emails, or phone numbers required
- **Ephemeral by Default**: Files exist only during transfer unless explicitly saved
- **Emergency Wipe**: Triple-tap to instantly clear all data
- **Local-First**: Works completely offline, no servers involved

### 📂 **File Sharing Capabilities** (bitshare Extensions)
- **Multiple File Types**: Documents, images, videos, archives
- **Progressive Transfer**: Resume interrupted transfers automatically
- **Compression**: Automatic file compression for faster transfers
- **Batch Operations**: Share multiple files simultaneously
- **File Integrity**: Cryptographic verification of transfer completion

### 🌐 **Mesh Networking** (Built on bitchat foundation)
- **Decentralized Mesh Network**: Automatic peer discovery and multi-hop file relay
- **Store & Forward**: Files cached for offline peers and delivered when they reconnect
- **Extended Range**: Reach distant peers through mesh relay (300m+ effective range)
- **Battery Optimization**: Adaptive power management for extended operation

### 🚀 **Performance Features**
- **LZ4 Compression**: 30-70% bandwidth savings on typical files
- **Adaptive Power Modes**: Battery-aware operation with multiple power levels
- **Background Transfers**: Continue sharing when app is backgrounded
- **Smart Retry**: Automatic retry with exponential backoff for failed transfers

## Technical Architecture

bitshare builds upon bitchat's proven technical foundation:

### Inherited from bitchat:
- **Binary Protocol**: Efficient packet format optimized for Bluetooth LE
- **Mesh Networking**: Multi-hop routing with TTL-based forwarding
- **Encryption Stack**: X25519 + AES-256-GCM + Ed25519 signatures
- **Privacy Features**: Cover traffic, timing obfuscation, ephemeral identities

### bitshare Extensions:
- **File Transfer Protocol**: Chunked transfer with integrity verification
- **Progress Tracking**: Real-time transfer status and completion tracking  
- **Resume Capability**: Automatic retry and resume for interrupted transfers
- **Compression Layer**: Intelligent compression based on file type and size

## Quick Start

### Prerequisites
- iOS 16.0+ / macOS 13.0+
- Xcode 14.0+
- XcodeGen (recommended): `brew install xcodegen`

### Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone https://github.com/the9ines/bitshare.git
   cd bitshare
   ```

2. **Run the renaming script** (if needed):
   ```bash
   ./rename_to_bitshare.sh
   ```

3. **Generate Xcode project**:
   ```bash
   xcodegen generate
   ```

4. **Open in Xcode**:
   ```bash
   open bitshare.xcodeproj
   ```

5. **Update Development Team**:
   - Open `project.yml`
   - Change `DEVELOPMENT_TEAM: L3N5LHJD5Y` to your team ID
   - Run `xcodegen generate` again

6. **Build and Run**:
   - Select your target device
   - Build and run the project

## Usage

### Basic File Sharing
1. Launch bitshare on your device
2. Set your nickname or use the auto-generated one
3. You'll automatically connect to nearby bitshare users
4. Select files to share using the interface
5. Choose recipients from discovered peers
6. Files transfer automatically through the mesh network

### Advanced Features
- **Batch Sharing**: Select multiple files for simultaneous transfer
- **Resume Transfers**: Interrupted transfers automatically resume when peers reconnect
- **File Organization**: Organize shared files into collections or topics
- **Transfer History**: Track completed and pending transfers

## Development

### Project Structure
```
bitshare/
├── bitshare/                 # Main app source
│   ├── bitshareApp.swift     # App entry point  
│   ├── Protocols/            # Core protocols (inherited from bitchat)
│   ├── Services/             # Bluetooth, encryption, file transfer
│   ├── Utils/                # Utilities and helpers
│   ├── ViewModels/           # MVVM view models
│   └── Views/                # SwiftUI views
├── bitshareShareExtension/   # iOS Share Extension
└── bitshareTests/           # Unit tests
```

### Key Components
- **File Transfer Service**: Manages chunked file transfers with progress tracking
- **Mesh Network Service**: Inherited from bitchat - handles peer discovery and routing
- **Encryption Service**: Inherited from bitchat - manages end-to-end encryption
- **Storage Service**: Manages temporary file storage and cleanup

### Building for Production
1. Set your development team in project settings
2. Configure code signing
3. Update bundle identifiers to your domain
4. Archive and distribute through App Store or TestFlight

## Contributing

We welcome contributions to bitshare! Please:

1. **Respect the Foundation**: Maintain compatibility with bitchat's core protocol
2. **Preserve Privacy**: Any new features must maintain the privacy-first approach
3. **Test Thoroughly**: Ensure new features work across the mesh network
4. **Follow Conventions**: Use the established code style and architecture

## License

This project is released into the public domain, following the original bitchat license. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Jack Dorsey** ([@jackjackbits](https://github.com/jackjackbits)) - Creator of the original bitchat protocol and mesh networking foundation
- **The bitchat community** - For the robust, privacy-focused communication protocol
- **The9ines** - For extending the platform to enable secure file sharing

## Support

- **Issues**: [GitHub Issues](https://github.com/the9ines/bitshare/issues)
- **Documentation**: [Technical Whitepaper](WHITEPAPER.md)
- **Privacy**: [Privacy Policy](PRIVACY_POLICY.md)

---

*bitshare: Building on Jack Dorsey's vision of decentralized communication to enable secure, private file sharing for everyone.*