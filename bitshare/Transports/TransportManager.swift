//
// TransportManager.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import Combine
import UIKit

// MARK: - Transport Manager

/// Intelligent coordinator for multiple transport protocols with automatic selection
@MainActor
class TransportManager: ObservableObject {
    static let shared = TransportManager()
    
    // MARK: - Published Properties
    @Published var availableTransports: [TransportType] = []
    @Published var activeTransports: Set<TransportType> = []
    @Published var allPeers: [PeerInfo] = []
    @Published var primaryTransport: TransportType = .bluetooth
    @Published var isDiscovering: Bool = false
    @Published var statistics: [TransportType: TransportStatistics] = [:]
    
    // MARK: - Private Properties
    private var transports: [TransportType: TransportProtocol] = [:]
    private var routingTable: [PeerID: Set<TransportType>] = [:]
    private var peerCapabilities: [PeerID: Set<TransportType>] = [:]
    private var transportObserver = TransportObserver()
    private let batteryOptimizer = BatteryOptimizer.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Enhanced security integration
    private let peerIDManager = PeerIDManager.shared
    private let noiseService = NoiseEncryptionService()
    private var peerVersions: [PeerID: ProtocolVersion] = [:]
    private var trustedPeers: Set<PeerID> = []
    private var securityEvents: [SecurityEvent] = []
    
    // Transport selection preferences
    private let fileTransferThreshold: Int = 1_000_000  // 1MB - switch to WiFi Direct for larger files
    private let batteryThreshold: Float = 0.5  // 50% - require this much battery for WiFi Direct
    private let messageSizeThreshold: Int = 1000  // 1KB - use BLE for smaller messages
    private let securityUpgradeThreshold: Int = 10_000_000  // 10MB - force WiFi Direct for large secure transfers
    
    // Performance tracking
    private var messageCount: [TransportType: Int] = [:]
    private var bytesSent: [TransportType: Int64] = [:]
    private var bytesReceived: [TransportType: Int64] = [:]
    private var connectionCount: [TransportType: Int] = [:]
    private var lastActivity: [TransportType: Date] = [:]
    
    private init() {
        setupBatteryMonitoring()
        setupTransportObserver()
        setupSecurityIntegration()
    }
    
    // MARK: - Security Integration
    
    private func setupSecurityIntegration() {
        // Set up Noise service callbacks
        noiseService.onSessionEstablished = { [weak self] peerID in
            self?.handleSessionEstablished(peerID)
        }
        
        noiseService.onVersionNegotiated = { [weak self] peerID, version in
            self?.peerVersions[peerID] = version
            self?.logSecurityEvent(.versionNegotiated(peerID: peerID, version: version))
        }
        
        noiseService.onRekeyComplete = { [weak self] peerID in
            self?.logSecurityEvent(.rekeyCompleted(peerID: peerID))
        }
        
        // Set up peer ID manager callbacks
        peerIDManager.onPeerIDRotated = { [weak self] oldID, newID in
            self?.handlePeerIDRotation(oldID: oldID, newID: newID)
        }
        
        peerIDManager.onPeerIDMapped = { [weak self] peerID, staticKey in
            self?.handlePeerIDMapping(peerID: peerID, staticKey: staticKey)
        }
    }
    
    private func handleSessionEstablished(_ peerID: PeerID) {
        Task { @MainActor in
            // Update peer trust status
            trustedPeers.insert(peerID)
            
            // Log security event
            logSecurityEvent(.sessionEstablished(peerID: peerID))
        }
    }
    
    private func handlePeerIDRotation(oldID: String, newID: String) {
        Task { @MainActor in
            // Update routing table
            if let transports = routingTable[oldID] {
                routingTable[newID] = transports
                routingTable.removeValue(forKey: oldID)
            }
            
            // Update peer capabilities
            if let capabilities = peerCapabilities[oldID] {
                peerCapabilities[newID] = capabilities
                peerCapabilities.removeValue(forKey: oldID)
            }
            
            // Update trusted peers
            if trustedPeers.contains(oldID) {
                trustedPeers.remove(oldID)
                trustedPeers.insert(newID)
            }
            
            // Log security event
            logSecurityEvent(.peerIDRotated(oldID: oldID, newID: newID))
        }
    }
    
    private func handlePeerIDMapping(peerID: String, staticKey: Data) {
        Task { @MainActor in
            // Add peer fingerprint to noise service
            noiseService.addPeerFingerprint(peerID, publicKey: staticKey)
            
            // Log security event
            logSecurityEvent(.peerMapped(peerID: peerID))
        }
    }
    
    private func logSecurityEvent(_ event: SecurityEvent) {
        securityEvents.append(event)
        
        // Keep only last 100 events to prevent memory growth
        if securityEvents.count > 100 {
            securityEvents.removeFirst()
        }
    }
    
    // MARK: - Transport Registration
    
    func registerTransport(_ transport: TransportProtocol) {
        transports[transport.transportType] = transport
        transport.delegate = transportObserver
        
        if transport.isAvailable {
            availableTransports.append(transport.transportType)
        }
        
        // Initialize statistics
        statistics[transport.transportType] = TransportStatistics(
            transportType: transport.transportType,
            messagesSent: 0,
            messagesReceived: 0,
            bytesSent: 0,
            bytesReceived: 0,
            connectionsEstablished: 0,
            connectionFailures: 0,
            averageLatency: 0.0,
            averageThroughput: 0.0,
            lastActivity: nil
        )
        
        print("[TransportManager] Registered \(transport.transportType.displayName) transport")
        
        // Set up enhanced security for this transport
        setupTransportSecurity(transport)
    }
    
    func unregisterTransport(_ transportType: TransportType) {
        if let transport = transports[transportType] {
            transport.stopDiscovery()
            transport.delegate = nil
            transports.removeValue(forKey: transportType)
            availableTransports.removeAll { $0 == transportType }
            activeTransports.remove(transportType)
            print("[TransportManager] Unregistered \(transportType.displayName) transport")
        }
    }
    
    private func setupTransportSecurity(_ transport: TransportProtocol) {
        // Initialize version negotiation for new transport
        if let noiseTransport = transport as? NoiseTransport {
            noiseTransport.setNoiseService(noiseService)
        }
    }
    
    // MARK: - Enhanced Transport Selection
    
    func selectOptimalTransport(for data: Data, to peerID: PeerID) -> TransportType {
        let dataSize = data.count
        let batteryLevel = batteryOptimizer.batteryLevel
        let peerCapabilities = peerCapabilities[peerID] ?? []
        
        // Security-first selection for large transfers
        if dataSize > securityUpgradeThreshold && peerCapabilities.contains(.wifiDirect) {
            logSecurityEvent(.transportSecurityUpgrade(peerID: peerID, from: .bluetooth, to: .wifiDirect))
            return .wifiDirect
        }
        
        // Standard selection logic with security considerations
        if dataSize > fileTransferThreshold && batteryLevel > batteryThreshold {
            // Large file - prefer WiFi Direct if available
            if peerCapabilities.contains(.wifiDirect) && availableTransports.contains(.wifiDirect) {
                return .wifiDirect
            }
        }
        
        if dataSize < messageSizeThreshold || batteryLevel < batteryThreshold {
            // Small message or low battery - prefer Bluetooth LE
            if peerCapabilities.contains(.bluetooth) && availableTransports.contains(.bluetooth) {
                return .bluetooth
            }
        }
        
        // Fallback to any available transport that peer supports
        for transport in availableTransports {
            if peerCapabilities.contains(transport) {
                return transport
            }
        }
        
        // Final fallback to primary transport
        return primaryTransport
    }
    
    // MARK: - Enhanced Message Sending
    
    func sendSecureMessage(_ data: Data, to peerID: PeerID?, via transportType: TransportType? = nil) {
        guard let targetPeer = peerID else {
            // Broadcast to all peers
            for peer in allPeers {
                sendSecureMessage(data, to: peer.id, via: transportType)
            }
            return
        }
        
        // First ensure we have a secure session
        guard noiseService.hasSession(with: targetPeer) else {
            // Initiate handshake first
            if let handshakeMessage = noiseService.initiateHandshake(with: targetPeer) {
                let transport = transportType ?? selectOptimalTransport(for: handshakeMessage.encode(), to: targetPeer)
                sendMessage(handshakeMessage.encode(), to: targetPeer, via: transport)
            }
            return
        }
        
        // Encrypt the message
        guard let encryptedMessage = noiseService.encryptMessage(data, for: targetPeer) else {
            logSecurityEvent(.securityViolation(peerID: targetPeer, reason: "Message encryption failed"))
            return
        }
        
        // Send via optimal transport
        let transport = transportType ?? selectOptimalTransport(for: encryptedMessage.encode(), to: targetPeer)
        sendMessage(encryptedMessage.encode(), to: targetPeer, via: transport)
    }
    
    private func sendMessage(_ data: Data, to peerID: PeerID, via transportType: TransportType) {
        guard let transport = transports[transportType] else {
            print("[TransportManager] Transport \(transportType.displayName) not available")
            return
        }
        
        // Create BitShare packet
        let packet = BitSharePacket(
            type: .encrypted,
            senderID: peerIDManager.currentPeerID,
            receiverID: peerID,
            data: data,
            timestamp: Date()
        )
        
        transport.send(packet, to: peerID)
        
        // Update statistics
        updateStatistics(for: transportType, messagesSent: 1, bytesSent: Int64(data.count))
    }
    
    // MARK: - Discovery Management
    
    func startDiscovery() throws {
        guard !transports.isEmpty else {
            throw TransportError.transportNotSupported
        }
        
        var errors: [Error] = []
        
        // Start discovery on all available transports
        for (type, transport) in transports {
            if transport.isAvailable {
                do {
                    try transport.startDiscovery()
                    activeTransports.insert(type)
                    print("[TransportManager] Started discovery on \(type.displayName)")
                } catch {
                    errors.append(error)
                    print("[TransportManager] Failed to start discovery on \(type.displayName): \(error)")
                }
            }
        }
        
        isDiscovering = !activeTransports.isEmpty
        
        // If all transports failed, throw the first error
        if activeTransports.isEmpty && !errors.isEmpty {
            throw errors.first!
        }
    }
    
    func stopDiscovery() {
        for transport in transports.values {
            transport.stopDiscovery()
        }
        activeTransports.removeAll()
        isDiscovering = false
        print("[TransportManager] Stopped discovery on all transports")
    }
    
    // MARK: - Intelligent Message Routing
    
    func sendOptimal(_ packet: BitchatPacket, to peerID: PeerID? = nil) throws {
        let selectedTransport = try selectOptimalTransport(
            for: packet,
            to: peerID,
            messageSize: packet.payload.count
        )
        
        guard let transport = transports[selectedTransport] else {
            throw TransportError.transportUnavailable(selectedTransport)
        }
        
        try transport.send(packet, to: peerID)
        updateStatistics(for: selectedTransport, messageSize: packet.payload.count, sent: true)
        
        print("[TransportManager] Sent message via \(selectedTransport.displayName) to \(peerID ?? "broadcast")")
    }
    
    func sendFile(_ data: Data, filename: String, to peerID: PeerID, progress: @escaping (Double) -> Void) throws {
        let selectedTransport = try selectOptimalTransport(
            for: nil,
            to: peerID,
            messageSize: data.count
        )
        
        guard let transport = transports[selectedTransport] else {
            throw TransportError.transportUnavailable(selectedTransport)
        }
        
        guard transport.canHandleFileSize(data.count) else {
            throw TransportError.fileTooLarge(data.count, transport.maxMessageSize)
        }
        
        try transport.sendFile(data, filename: filename, to: peerID, progress: progress)
        updateStatistics(for: selectedTransport, messageSize: data.count, sent: true)
        
        print("[TransportManager] Sending file '\(filename)' (\(data.count) bytes) via \(selectedTransport.displayName)")
    }
    
    // MARK: - Transport Selection Algorithm
    
    private func selectOptimalTransport(for packet: BitchatPacket?, to peerID: PeerID?, messageSize: Int) throws -> TransportType {
        // Get available transports for this peer
        let availableForPeer = getAvailableTransportsForPeer(peerID)
        
        guard !availableForPeer.isEmpty else {
            throw TransportError.peerNotFound(peerID ?? "broadcast")
        }
        
        let batteryLevel = batteryOptimizer.batteryLevel
        let isCharging = batteryOptimizer.isCharging
        
        // Decision matrix based on Jack's plan
        
        // 1. Large files (>1MB) with good battery or charging -> WiFi Direct
        if messageSize > fileTransferThreshold {
            if availableForPeer.contains(.wifiDirect) && 
               (batteryLevel > batteryThreshold || isCharging) {
                return .wifiDirect
            }
        }
        
        // 2. Small messages (<1KB) or low battery -> Bluetooth LE
        if messageSize < messageSizeThreshold || batteryLevel < 0.3 {
            if availableForPeer.contains(.bluetooth) {
                return .bluetooth
            }
        }
        
        // 3. Medium size with good battery -> prefer faster transport
        if batteryLevel > batteryThreshold && availableForPeer.contains(.wifiDirect) {
            return .wifiDirect
        }
        
        // 4. Fallback to most reliable available transport
        if availableForPeer.contains(.bluetooth) {
            return .bluetooth
        }
        
        // 5. Last resort - any available transport
        return availableForPeer.first!
    }
    
    private func getAvailableTransportsForPeer(_ peerID: PeerID?) -> Set<TransportType> {
        guard let peerID = peerID else {
            // For broadcast, use all active transports
            return activeTransports
        }
        
        // Check routing table for peer-specific transports
        if let peerTransports = routingTable[peerID] {
            return peerTransports.intersection(activeTransports)
        }
        
        // Fallback to all active transports
        return activeTransports
    }
    
    // MARK: - Connection Management
    
    func connectToPeer(_ peerID: PeerID, preferredTransport: TransportType? = nil) throws {
        let transportType = preferredTransport ?? primaryTransport
        
        guard let transport = transports[transportType],
              transport.isAvailable else {
            throw TransportError.transportUnavailable(transportType)
        }
        
        // Find peer info
        guard let peerInfo = allPeers.first(where: { $0.id == peerID && $0.transportType == transportType }) else {
            throw TransportError.peerNotFound(peerID)
        }
        
        try transport.connect(to: peerInfo)
        print("[TransportManager] Connecting to \(peerID) via \(transportType.displayName)")
    }
    
    func disconnectFromPeer(_ peerID: PeerID, transport: TransportType? = nil) {
        if let specificTransport = transport,
           let transportInstance = transports[specificTransport] {
            transportInstance.disconnect(from: peerID)
        } else {
            // Disconnect from all transports
            for transportInstance in transports.values {
                transportInstance.disconnect(from: peerID)
            }
        }
        
        // Update routing table
        routingTable[peerID]?.removeAll()
        
        print("[TransportManager] Disconnected from \(peerID)")
    }
    
    // MARK: - Transport Health and Quality
    
    func getConnectionQuality(for peerID: PeerID) -> ConnectionQuality {
        var bestQuality: ConnectionQuality = .poor
        
        for (_, transport) in transports {
            let quality = transport.getConnectionQuality(for: peerID)
            if quality > bestQuality {
                bestQuality = quality
            }
        }
        
        return bestQuality
    }
    
    func getPreferredTransport(for peerID: PeerID) -> TransportType? {
        guard let peerTransports = routingTable[peerID] else { return nil }
        
        // Prefer WiFi Direct for file transfers if available and battery is good
        if peerTransports.contains(.wifiDirect) && batteryOptimizer.batteryLevel > batteryThreshold {
            return .wifiDirect
        }
        
        // Fallback to Bluetooth for reliability
        if peerTransports.contains(.bluetooth) {
            return .bluetooth
        }
        
        return peerTransports.first
    }
    
    // MARK: - Statistics and Monitoring
    
    private func updateStatistics(for transportType: TransportType, messageSize: Int, sent: Bool) {
        if sent {
            messageCount[transportType, default: 0] += 1
            bytesSent[transportType, default: 0] += Int64(messageSize)
        } else {
            bytesReceived[transportType, default: 0] += Int64(messageSize)
        }
        
        lastActivity[transportType] = Date()
        
        // Update published statistics
        updatePublishedStatistics(for: transportType)
    }
    
    private func updatePublishedStatistics(for transportType: TransportType) {
        let sent = messageCount[transportType] ?? 0
        let received = 0 // Will be updated by delegate
        let bytesSentValue = bytesSent[transportType] ?? 0
        let bytesReceivedValue = bytesReceived[transportType] ?? 0
        let connections = connectionCount[transportType] ?? 0
        let failures = 0 // Will be tracked by delegate
        
        statistics[transportType] = TransportStatistics(
            transportType: transportType,
            messagesSent: sent,
            messagesReceived: received,
            bytesSent: bytesSentValue,
            bytesReceived: bytesReceivedValue,
            connectionsEstablished: connections,
            connectionFailures: failures,
            averageLatency: 0.0, // TODO: Calculate from latency measurements
            averageThroughput: 0.0, // TODO: Calculate from throughput measurements
            lastActivity: lastActivity[transportType]
        )
    }
    
    // MARK: - Battery Monitoring
    
    private func setupBatteryMonitoring() {
        // Monitor battery changes to adjust transport preferences
        batteryOptimizer.$batteryLevel
            .sink { [weak self] batteryLevel in
                self?.handleBatteryLevelChange(batteryLevel)
            }
            .store(in: &cancellables)
        
        batteryOptimizer.$isCharging
            .sink { [weak self] isCharging in
                self?.handleChargingStateChange(isCharging)
            }
            .store(in: &cancellables)
    }
    
    private func handleBatteryLevelChange(_ batteryLevel: Float) {
        // Disable WiFi Direct if battery is too low
        if batteryLevel < 0.3 && activeTransports.contains(.wifiDirect) {
            if let wifiTransport = transports[.wifiDirect] {
                wifiTransport.stopDiscovery()
                activeTransports.remove(.wifiDirect)
                print("[TransportManager] Disabled WiFi Direct due to low battery (\(Int(batteryLevel * 100))%)")
            }
        }
        
        // Re-enable WiFi Direct if battery recovers
        if batteryLevel > batteryThreshold && !activeTransports.contains(.wifiDirect) {
            if let wifiTransport = transports[.wifiDirect], wifiTransport.isAvailable {
                do {
                    try wifiTransport.startDiscovery()
                    activeTransports.insert(.wifiDirect)
                    print("[TransportManager] Re-enabled WiFi Direct with sufficient battery (\(Int(batteryLevel * 100))%)")
                } catch {
                    print("[TransportManager] Failed to re-enable WiFi Direct: \(error)")
                }
            }
        }
    }
    
    private func handleChargingStateChange(_ isCharging: Bool) {
        if isCharging {
            // Enable all available transports when charging
            for (type, transport) in transports {
                if transport.isAvailable && !activeTransports.contains(type) {
                    do {
                        try transport.startDiscovery()
                        activeTransports.insert(type)
                        print("[TransportManager] Enabled \(type.displayName) while charging")
                    } catch {
                        print("[TransportManager] Failed to enable \(type.displayName): \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Transport Observer Setup
    
    private func setupTransportObserver() {
        transportObserver.addDelegate(self)
    }
}

// MARK: - TransportDelegate Implementation

extension TransportManager: TransportDelegate {
    func transport(_ transport: TransportProtocol, didDiscoverPeer peer: PeerInfo) {
        // Add to peer list if not already present
        if !allPeers.contains(where: { $0.id == peer.id && $0.transportType == peer.transportType }) {
            allPeers.append(peer)
        }
        
        // Update routing table
        routingTable[peer.id, default: Set()].insert(peer.transportType)
        
        // Store peer capabilities
        peerCapabilities[peer.id] = peer.supportedTransports
        
        print("[TransportManager] Discovered peer \(peer.nickname) via \(peer.transportType.displayName)")
    }
    
    func transport(_ transport: TransportProtocol, didLosePeer peer: PeerInfo) {
        // Remove from peer list
        allPeers.removeAll { $0.id == peer.id && $0.transportType == peer.transportType }
        
        // Update routing table
        routingTable[peer.id]?.remove(peer.transportType)
        if routingTable[peer.id]?.isEmpty == true {
            routingTable.removeValue(forKey: peer.id)
            peerCapabilities.removeValue(forKey: peer.id)
        }
        
        print("[TransportManager] Lost peer \(peer.nickname) via \(peer.transportType.displayName)")
    }
    
    func transport(_ transport: TransportProtocol, didConnectTo peer: PeerInfo) {
        connectionCount[transport.transportType, default: 0] += 1
        updatePublishedStatistics(for: transport.transportType)
        
        print("[TransportManager] Connected to \(peer.nickname) via \(transport.transportType.displayName)")
    }
    
    func transport(_ transport: TransportProtocol, didDisconnectFrom peer: PeerInfo) {
        print("[TransportManager] Disconnected from \(peer.nickname) via \(transport.transportType.displayName)")
    }
    
    func transport(_ transport: TransportProtocol, didReceivePacket packet: BitchatPacket, from peer: PeerInfo) {
        updateStatistics(for: transport.transportType, messageSize: packet.payload.count, sent: false)
        
        // Forward to appropriate handlers (will be implemented by specific transport delegates)
        print("[TransportManager] Received packet from \(peer.nickname) via \(transport.transportType.displayName)")
    }
    
    func transport(_ transport: TransportProtocol, didChangeAvailability isAvailable: Bool) {
        if isAvailable && !availableTransports.contains(transport.transportType) {
            availableTransports.append(transport.transportType)
        } else if !isAvailable {
            availableTransports.removeAll { $0 == transport.transportType }
            activeTransports.remove(transport.transportType)
        }
        
        print("[TransportManager] \(transport.transportType.displayName) availability: \(isAvailable)")
    }
}