# Claude Configuration for BitShare Project

## Project Overview
BitShare is a native iOS/macOS file sharing application that extends the "bit ecosystem" by enabling secure, offline file transfers over Bluetooth mesh networks. This project follows the comprehensive specifications in `bitshare-prd-v1.0.md`.

## Critical Instructions

### 1. Always Reference the PRD
**BEFORE implementing any feature, always check the PRD first:**
- File: `bitshare-prd-v1.0.md`
- Every feature MUST be defined in the PRD
- Do NOT implement features not specified in the PRD
- Do NOT exceed the scope defined in the PRD

### 2. Scope Control
**Only implement features explicitly defined in PRD Section 5.1 (Essential Features):**
- ✅ Direct peer file sharing (private mode)
- ✅ Group/channel file sharing (password-protected)
- ✅ Transfer management (accept/reject/pause/resume/cancel)
- ✅ Store-and-forward for offline peers
- ✅ Peer management (blocking, reputation, nicknames)
- ✅ Multi-transport support (BLE + WiFi Direct)
- ✅ Drag & drop interface (NO IRC commands)
- ✅ Transfer progress tracking
- ✅ File integrity verification

**Do NOT implement these (not in PRD):**
- ❌ IRC-style commands (replaced with GUI)
- ❌ Command autocomplete (not needed)
- ❌ Link preview (not relevant for files)
- ❌ Cover traffic (overkill)
- ❌ Complex channel management (keep simple)

### 3. Technical Specifications
**Follow PRD Section 4 exactly:**
- **Visual Identity (Section 4.1)**: SF Mono typography, #00FF00 accent, black/white backgrounds
- **UI Layout (Section 4.2)**: Header (44px), file drop zone, peer controls
- **Protocol Compliance (Section 4.3)**: bitchat protocol compatibility
- **WiFi Direct Integration (Section 4.4)**: Multi-transport with intelligent routing
- **Noise Protocol Security (Section 4.5)**: End-to-end encryption

### 4. Implementation Guidelines

#### File Sharing Focus
- Replace bitchat's messaging with file transfer functionality
- Maintain same UI/UX patterns but for files instead of messages
- Keep security model (Noise Protocol, end-to-end encryption)
- Preserve mesh networking capabilities

#### Transport System
- Use existing TransportManager implementation
- WiFiDirectTransport for high-speed transfers (15x faster)
- NoiseTransport for encrypted BLE communication
- Intelligent routing based on file size and battery

#### UI/UX Requirements
- Drag & drop files to specific peers
- Transport status indicators
- Right-click context menus
- Transfer queue management
- Visual feedback for all operations

### 5. Testing & Validation
**Validate against PRD requirements:**
- **Section 8.2**: Performance metrics (transfer success rates, speeds)
- **Section 6.2**: User experience (intuitive file sharing)
- **Section 4.1**: Visual consistency (green theme, spacing)
- **Section 4.3**: Protocol compatibility (bitchat interoperability)

### 6. Backup Instructions
**Critical workflows for bitshare:**

Before making changes:
```bash
# Backup current state
git add .
git commit -m "Backup before changes"
git push origin main
```

File transfer testing:
```bash
# Test multi-transport functionality
# Verify WiFi Direct selection for large files
# Test BLE fallback for small files
# Validate Noise Protocol encryption
```

## Project Structure Reference
**Key files to understand:**
- `bitshare-prd-v1.0.md` - Complete requirements
- `WIFI_DIRECT_PLAN.md` - Transport implementation details
- `bitshare/Services/FileTransferManager.swift` - Core file transfer logic
- `bitshare/Transports/TransportManager.swift` - Multi-transport coordination
- `bitshare/Services/NoiseEncryptionService.swift` - Security layer

## Success Criteria
**Project is complete when:**
- ✅ All PRD Section 5.1 features implemented
- ✅ Visual consistency with bitchat (PRD Section 4.1)
- ✅ Multi-transport file sharing works (BLE + WiFi Direct)
- ✅ Noise Protocol encryption integrated
- ✅ Performance meets PRD metrics (Section 8.2)
- ✅ User experience is intuitive (PRD Section 6.2)

## Important Notes
- **bitchat compatibility**: Must work with Jack's bitchat mesh network
- **No feature creep**: Only implement what's in the PRD
- **File sharing focus**: Not a chat replacement, focused on files
- **Security first**: Maintain Noise Protocol encryption
- **Performance**: WiFi Direct for speed, BLE for efficiency

## Development Process
1. **Check PRD** for feature requirements
2. **Implement only** what's specified
3. **Test against** PRD success criteria
4. **Validate** with existing codebase
5. **Document** changes made

Remember: The PRD is the single source of truth. When in doubt, check the PRD first.