# BitShare Product Requirements Document (PRD)

## Executive Summary

BitShare is a native iOS/macOS file sharing application designed to facilitate secure, offline file transfers leveraging the Bluetooth mesh network established by Jack Dorsey's Bitchat. It is built for privacy-conscious individuals, emergency responders, and anyone operating in connectivity-constrained environments. BitShare matters now more than ever as it provides a critical, decentralized alternative for data exchange, ensuring communication and collaboration even when traditional infrastructure fails. Its key differentiators include complete offline functionality, 100% visual and technical consistency with the proven Bitchat protocol, multi-hop file transfer capabilities, and robust end-to-end encryption, all developed rapidly by forking and extending an existing battle-tested open-source codebase.

## Table of Contents

1. [Introduction](#introduction)
2. [Background & Context](#background--context)
   - [The Bit Ecosystem Vision](#the-bit-ecosystem-vision)
   - [BitShare Product Overview](#bitshare-product-overview)
3. [Technical Foundation](#technical-foundation)
   - [Bitchat Protocol Details](#bitchat-protocol-details)
   - [File Transfer Adaptations](#file-transfer-adaptations)
4. [Design System Requirements](#design-system-requirements)
   - [Visual Identity](#visual-identity)
   - [UI Layout Pattern](#ui-layout-pattern)
5. [Core Features & Functionality](#core-features--functionality)
   - [Essential Features (MVP)](#essential-features-mvp)
   - [Advanced Features (Post-MVP)](#advanced-features-post-mvp)
   - [Feature Summary: MVP vs. Advanced](#feature-summary-mvp-vs-advanced)
6. [Target Users & Use Cases](#target-users--use-cases)
   - [Primary Users](#primary-users)
   - [Key Use Cases](#key-use-cases)
7. [Technical Architecture](#technical-architecture)
   - [Platform Strategy](#platform-strategy)
   - [Core Components](#core-components)
   - [Integration Points](#integration-points)
   - [Technical Unknowns](#technical-unknowns)
8. [Success Metrics & KPIs](#success-metrics--kpis)
   - [Adoption Metrics](#adoption-metrics)
   - [Performance Metrics](#performance-metrics)
   - [Ecosystem Metrics](#ecosystem-metrics)
9. [Development Roadmap](#development-roadmap)
   - [Phase 0: Setup & Analysis](#phase-0-setup--analysis)
   - [Phase 1: UI & Core Logic Replacement](#phase-1-ui--core-logic-replacement)
   - [Phase 2: Protocol Extension & Advanced Features](#phase-2-protocol-extension--advanced-features)
   - [Phase 3: Testing, Refinement & Launch](#phase-3-testing-refinement--launch)
   - [Phase 4: Expansion](#phase-4-expansion)
10. [Strategic Considerations](#strategic-considerations)
    - [Ecosystem Strategy](#ecosystem-strategy)
    - [Business Model](#business-model)
    - [Risk Mitigation](#risk-mitigation)
11. [Regulatory & Compliance](#regulatory--compliance)
    - [Privacy Requirements](#privacy-requirements)
    - [Platform Compliance](#platform-compliance)
12. [Legal & Attribution](#legal--attribution)
    - [The Unlicense (Public Domain Dedication)](#the-unlicense-public-domain-dedication)
    - [Ethical Attribution Statement](#ethical-attribution-statement)
    - [Warranty Disclaimer Emphasis](#warranty-disclaimer-emphasis)
    - [Clear Documentation of Modifications](#clear-documentation-of-modifications)
    - [Contribution Strategy](#contribution-strategy)
13. [Technical Benefits of Forking](#technical-benefits-of-forking)
14. [Community-Driven Development Model](#community-driven-development-model)
15. [Conclusion](#conclusion)

## Introduction

This document outlines the comprehensive Product Requirements Document for BitShare, a native iOS/macOS file sharing application designed to operate entirely offline via Bluetooth mesh networking. BitShare is the inaugural expansion of the "bit ecosystem," leveraging the proven Bluetooth mesh protocol and visual design established by Jack Dorsey's "Bitchat" decentralized messaging app. Crucially, BitShare will be developed by forking and modifying the existing open-source Bitchat codebase, ensuring unparalleled consistency and accelerating development. This PRD serves as a complete blueprint for the development, testing, and launch of BitShare, ensuring its seamless integration into the broader offline-first application ecosystem.

## Background & Context

### The Bit Ecosystem Vision

Jack Dorsey's "Bitchat" has demonstrated the viability and critical need for decentralized, offline messaging over Bluetooth Low Energy (BLE) mesh networks. Its core features, including end-to-end encryption, automatic peer discovery, and multi-hop message relaying, provide a robust communication solution in scenarios where internet connectivity is absent or compromised (e.g., natural disasters, censorship, remote areas).

Our vision is to expand upon this foundational technology by creating a comprehensive "bit ecosystem" – a suite of offline-capable applications that all utilize Bitchat's established Bluetooth mesh protocol and adhere to its strict design principles. This ecosystem aims to provide essential digital tools that function reliably without reliance on central servers or internet access.

### BitShare Product Overview

BitShare is the first application to extend the bit ecosystem. It is designed as a native iOS/macOS file sharing application that facilitates completely offline file transfers over Bluetooth mesh. A critical aspect of BitShare's design is its commitment to 100% visual and architectural consistency with Bitchat, ensuring a cohesive and intuitive user experience across the ecosystem.

#### Core Concept

BitShare enables users to select and transfer files to other nearby devices within the Bluetooth mesh network. Files are chunked, encrypted, and relayed across intermediate devices, extending the effective range of file transfers beyond direct Bluetooth proximity. Users can intuitively manage transfers, track progress, and ensure data integrity.

#### Key Differentiators

- Works Completely Offline  
- Bitchat Visual & Technical Consistency  
- Native Performance  
- Multi-hop File Transfer  
- End-to-End Encryption  
- Cross-platform Protocol Compatibility  

## Technical Foundation

### Bitchat Protocol Details

BitShare will build directly upon the Bitchat protocol, ensuring interoperability and leveraging its proven robustness.

- Bluetooth Low Energy Mesh Networking
- Binary Protocol
- 13-byte Header Format
- TTL-based Routing
- X25519 Key Exchange + AES-256-GCM Encryption
- Store-and-Forward Mechanism
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Characteristic UUID: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`

### File Transfer Adaptations

The Bitchat protocol will be extended with:

- FILE_MANIFEST
- FILE_CHUNK
- FILE_ACK

Including chunking, reassembly, integrity verification, progress tracking, and resume capabilities.

### Multi-Transport Architecture

BitShare implements a sophisticated multi-transport system for optimal file transfer performance:

#### Transport Layer Abstraction
- **TransportProtocol Interface**: Unified API for all transport mechanisms
- **TransportManager**: Intelligent coordinator for multiple transport protocols
- **Automatic Transport Selection**: Based on file size, battery level, and peer capabilities

#### WiFi Direct Integration
- **Framework**: iOS MultipeerConnectivity, macOS Network.framework
- **Performance**: 10-100x faster than Bluetooth LE (250+ Mbps vs 1-3 Mbps)
- **Range**: 100-200 meters vs BLE's 10-30 meters
- **Power Management**: Only activated when beneficial (large files, good battery)
- **Security**: Same encryption as BLE (Noise Protocol + AES-256-GCM)

#### Noise Protocol Security
- **End-to-End Encryption**: All transports use Noise Protocol Framework
- **Forward Secrecy**: Automatic 60-second key rotation
- **Identity Protection**: Handshake encrypted, peer authentication
- **Session Management**: Automatic session establishment and cleanup

#### Intelligent Routing Algorithm
```
File Size < 1MB + Battery < 50% → Bluetooth LE
File Size > 1MB + Battery > 50% → WiFi Direct
Emergency/Broadcast → All available transports
```

## Design System Requirements

### Visual Identity

- **Typography:** SF Mono  
- **Accent Color:** #00FF00  
- **Backgrounds:** Black and white  
- **Component Styling:** Match Bitchat exactly  
- **Spacing:** Horizontal 12px, Vertical 8px  
- **Animations:** Spring with 0.3 response and 0.8 damping

### UI Layout Pattern

```
┌─────────────────────────────────────┐
│ bitshare [🔐 Noise] [⚡ WiFi: 3]    │  Header (44px) - App title + Transport status
├─────────────────────────────────────┤
│                                     │
│     📁 Drag files here              │  File Drop Zone - Main content area
│     or click to select              │  - Drag files to specific peers
│                                     │  - Right-click context menus
│     [Active Transfers]              │  - Transfer progress indicators
│     ▓▓▓▓▓▓▓▓░░ 80% photo.jpg        │
│                                     │
├─────────────────────────────────────┤
│ 👥 Peers: Alice📱 Bob💻 Charlie📲   │  Peer Controls - Connected peers
│ [🔵 BLE]  [🟢 WiFi Direct]         │  - Transport selection buttons
└─────────────────────────────────────┘
```

#### Enhanced UI Features
- **Drag-to-Peer**: Drag files directly onto peer icons for direct sharing
- **Transport Indicators**: Visual badges showing active transport and speed
- **Transfer Queue**: Real-time progress bars for active transfers
- **Peer Status**: Connection quality and transport capability indicators
- **Context Menus**: Right-click for share, send to, broadcast options
- **Sidebar**: Swipe-accessible settings and transfer history (iOS/macOS)

## Core Features & Functionality

### Essential Features (MVP)

#### Core File Sharing
- **Direct Peer File Sharing**: Click on peer to share files directly (private mode) ✅
- **Group/Channel File Sharing**: Password-protected shared folders for teams ✅
- **Drag-and-Drop Interface**: Intuitive file selection and sharing (no IRC commands) ⚠️
- **Multi-File Transfer**: Select and transfer multiple files simultaneously ✅
- **Transfer Management**: Accept/reject/pause/resume/cancel transfers ✅

#### Multi-Transport System
- **Bluetooth LE Support**: Encrypted mesh networking with Noise Protocol ✅
- **WiFi Direct Integration**: High-speed transfers (15x faster than BLE) ✅
- **Intelligent Transport Selection**: Automatic based on file size and battery ✅
- **Transport Status Indicators**: Visual feedback showing active transport ⚠️
- **Seamless Transport Handoff**: Automatic switching between BLE and WiFi ✅

#### Peer Management
- **Peer Discovery**: Automatic discovery of nearby BitShare users ✅
- **Peer Blocking/Unblocking**: Control which peers can send files ✅
- **Nickname Management**: Assign friendly names to peers ✅
- **Connection Quality**: Signal strength and connection status indicators ⚠️

#### Transfer Features
- **Progress Tracking**: Real-time transfer progress with speed indicators ✅
- **File Integrity Verification**: SHA-256 checksums for data integrity ✅
- **Store-and-Forward**: Queue files for offline peers, deliver on reconnection ✅
- **Transfer History**: View completed, failed, and pending transfers ⚠️
- **Retry Mechanisms**: Automatic retry for failed transfers ✅

#### Security & Privacy
- **Noise Protocol Encryption**: End-to-end encryption for all transfers ✅
- **Forward Secrecy**: Automatic 60-second key rotation ✅
- **Session Management**: Secure session establishment and cleanup ✅
- **Privacy Protection**: No data collection, local-only storage ✅

### Implementation Status Summary

#### ✅ Completed Features (Backend)
- Multi-transport architecture (WiFi Direct + Bluetooth LE)
- Noise Protocol encryption and security
- File transfer management and progress tracking
- Peer discovery and management
- Store-and-forward messaging
- Intelligent transport selection

#### ⚠️ UI Features Needing Implementation
- Drag-and-drop file interface
- Transport status indicators in UI
- Connection quality indicators
- Transfer history view
- Real-time progress bars

#### 🎯 Core MVP Requirements
The essential features marked with ⚠️ above are the minimum requirements to complete the MVP. All backend functionality is complete.

### Advanced Features (Post-MVP)

- Large File Chunking and Parallel Transfer
- Folder/Directory Transfer Support
- Transfer Scheduling and Queuing
- Bandwidth Limiting and QoS Controls
- Cross-platform Compatibility
- Integration with Bitchat

### Feature Summary: MVP vs. Advanced

| Feature                        | MVP | Post-MVP |
|--------------------------------|-----|----------|
| Single file transfer           | ✅  |          |
| Multi-file transfer            | ✅  |          |
| Folder transfer                |     | ✅       |
| Pause/resume                   | ✅  |          |
| Transfer scheduling            |     | ✅       |
| Cross-platform compatibility   |     | ✅       |
| Large file chunking/parallel   |     | ✅       |
| Bandwidth limiting/QoS         |     | ✅       |
| Integration with Bitchat       |     | ✅       |

## Target Users & Use Cases

### Primary Users

- Privacy-conscious individuals
- Professionals in connectivity-constrained areas
- Emergency responders and disaster relief workers
- Content creators needing large local transfers
- Educators and students in offline settings

### Key Use Cases

- Disaster Scenarios
- Privacy-First Sharing
- Bandwidth-Limited Environments
- Local Collaboration
- Remote Area Operations

## Technical Architecture

### Platform Strategy

- Native iOS Application
- Native macOS Application
- Conceptual Web Version (future)
- Android Native App (future)

### Current Implementation Status

BitShare's core architecture is complete with WiFi Direct and Noise Protocol integration:

#### Multi-Transport Implementation ✅
- **TransportManager.swift**: Intelligent transport coordination
- **NoiseTransport.swift**: Encrypted Bluetooth LE with Noise Protocol
- **WiFiDirectTransport.swift**: High-speed WiFi Direct transport
- **Transport Selection**: Automatic routing based on file size and battery

#### Security Layer ✅
- **NoiseEncryptionService.swift**: Complete Noise Protocol Framework
- **Session Management**: 60-second key rotation with forward secrecy
- **Peer Authentication**: SHA256 fingerprint verification
- **End-to-End Encryption**: All transports use AES-256-GCM

#### File Transfer System ✅
- **FileTransferManager.swift**: Multi-transport file transfer coordination
- **Chunking System**: Optimized for different transport types
- **Progress Tracking**: Real-time transfer progress with speed indicators
- **Store-and-Forward**: Queue files for offline peers

### Core Components

Built by directly modifying Bitchat's codebase for maximum consistency and development acceleration.

#### Transport Layer (Multi-Transport Architecture)
- **TransportProtocol.swift**: Unified interface for all transport mechanisms
- **TransportManager.swift**: Intelligent coordinator for multiple transport protocols
- **NoiseTransport.swift**: Encrypted Bluetooth LE transport with Noise Protocol
- **WiFiDirectTransport.swift**: High-speed WiFi Direct transport using MultipeerConnectivity
- **TransportDelegate.swift**: Event handling for transport operations

#### Security Layer (Noise Protocol Implementation)
- **NoiseEncryptionService.swift**: Core Noise Protocol Framework implementation
- **KeychainManager.swift**: Secure key storage and management
- **Session Management**: Automatic 60-second key rotation and forward secrecy
- **Peer Authentication**: SHA256 fingerprint verification and identity protection

#### File Transfer System
- **FileTransferManager.swift**: Core file transfer logic with multi-transport support
- **FileTransferService.swift**: File chunking, reassembly, and integrity verification
- **FileTransferProtocol.swift**: Protocol definitions for file transfer operations
- **FileChunkOptimizer.swift**: Optimized chunking for different transport types

#### Network Services
- **BluetoothMeshService.swift**: Bluetooth LE mesh networking (adapted from bitchat)
- **MessageRetentionService.swift**: Store-and-forward for offline peers
- **DeliveryTracker.swift**: Track file delivery status and confirmation
- **MessageRetryService.swift**: Automatic retry for failed transfers
- **NotificationService.swift**: System notifications for file transfers

#### User Interface
- **ContentView.swift**: Main application interface with file drop zone
- **FileTransferProgressView.swift**: Real-time transfer progress indicators
- **TransportStatusView.swift**: Transport status and selection interface
- **FileTransferHistoryView.swift**: Transfer history and management
- **LinkPreviewView.swift**: File preview and metadata display

#### Utility Components
- **BatteryOptimizer.swift**: Battery-aware transport selection
- **CompressionUtil.swift**: File compression for efficient transfers
- **OptimizedBloomFilter.swift**: Efficient duplicate detection
- **BinaryProtocol.swift**: Bitchat-compatible binary protocol implementation

### Integration Points

- Full Protocol Compatibility with Bitchat Mesh Networks
- Shared Peer Discovery
- Cross-App Communication Capabilities

### Technical Unknowns

- BLE Throughput Limitations
- Chunk Loss Rates & Retransmission Performance
- Multi-hop Latency Concerns
- Realistic Performance KPIs

## Success Metrics & KPIs

### Adoption Metrics

- Monthly Active Users (MAU)
- Cross-App Usage
- Geographic Mesh Density
- Download Counts

### Performance Metrics

#### File Transfer Performance
- **File Transfer Success Rate**: >95% for files under 100MB
- **Average Transfer Speed**: 
  - WiFi Direct: 250+ Mbps (direct), 150+ Mbps (2-hop)
  - Bluetooth LE: 1-3 Mbps (direct), 0.5-1 Mbps (2-hop)
- **Connection Establishment Time**: <2 seconds for peer discovery
- **Transfer Resumption**: 100% success rate after connection loss

#### WiFi Direct Benchmarks
- **Range Performance**: 100-200 meters line-of-sight
- **Speed Advantage**: 15-100x faster than Bluetooth LE
- **Battery Impact**: <20% additional drain for transfers >10MB
- **Handoff Time**: <500ms switching between BLE and WiFi Direct

#### Noise Protocol Security Metrics
- **Encryption Overhead**: <5% performance impact
- **Key Rotation**: 60-second automatic rekey
- **Session Establishment**: <100ms for initial handshake
- **Forward Secrecy**: 100% message unrecoverability after key rotation

### Ecosystem Metrics

- Simultaneous Mesh Participants
- Average Mesh Size & Hop Distance
- Cross-platform Compatibility Rates
- Development Velocity
- Code Reuse Percentage

## Development Roadmap

### Phase 0: Setup & Analysis

Week 1

### Phase 1: UI & Core Logic Replacement

Weeks 2–4

### Phase 2: Protocol Extension & Advanced Features

Weeks 5–7

### Phase 3: Testing, Refinement & Launch

Weeks 8–10

### Phase 4: Expansion

Ongoing

## Strategic Considerations

### Ecosystem Strategy

- Complementary, not competitive with Bitchat
- Strict protocol compatibility
- Contribute improvements back to Bitchat
- Foundation for future bit ecosystem apps

### Business Model

- Open-source, community-driven
- No VC funding or stakeholders
- Potential enterprise support/custom services

### Risk Mitigation

- Technical: Fork maintenance, performance optimization
- Legal: Open-source license compliance
- Market: Adoption in niche offline-first markets

## Regulatory & Compliance

### Privacy Requirements

- No Data Collection or Analytics
- Local-only File Storage
- Mandatory End-to-End Encryption

### Platform Compliance

- iOS App Store Guidelines
- macOS Notarization & Permissions
- Transparent Bluetooth Usage Notices

## Legal & Attribution

### The Unlicense (Public Domain Dedication)

### Ethical Attribution Statement

### Warranty Disclaimer Emphasis

### Clear Documentation of Modifications

### Contribution Strategy

## Technical Benefits of Forking

- Guaranteed UI Consistency
- Proven Protocol
- Faster Development Timeline
- Lower Technical Risk
- Seamless Ecosystem Integration

## Community-Driven Development Model

- Public open-source repositories
- Clear contribution guidelines
- Transparent development discussions
- Alignment with Jack’s public domain vision

## Conclusion

BitShare represents a critical expansion of the "bit ecosystem," addressing the fundamental need for reliable, secure, and offline file sharing. By forking and modifying Bitchat's proven codebase, BitShare ensures technical excellence, rapid development, and strategic alignment with the decentralized offline-first vision. Successful implementation will solidify the foundation for future innovations in off-grid applications.

