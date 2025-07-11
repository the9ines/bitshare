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
│ bitshare* [peers: 3]                │  Header (44px fixed height)
├─────────────────────────────────────┤
│ File Drop Zone / Transfer Area      │  Main content area (scrollable if needed)
├─────────────────────────────────────┤
│ Peer Discovery / Controls           │  Bottom section (variable height)
└─────────────────────────────────────┘
```

## Core Features & Functionality

### Essential Features (MVP)

- Bluetooth Mesh Peer Discovery and Connection
- Drag-and-Drop File Selection Interface
- Multi-File Transfer with Progress Tracking
- Transfer Pause/Resume Capabilities
- File Integrity Verification (SHA-256)
- Automatic Transport Optimization (Direct vs. Multi-hop)
- Transfer History and Retry Mechanisms

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

### Core Components

Built by directly modifying Bitchat's codebase for maximum consistency and development acceleration.

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

- File Transfer Success Rate
- Average Transfer Speed (multi-hop)
- Connection Establishment Time
- Battery Usage Optimization

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

