//
// TransportProtocol.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit

// MARK: - Transport Protocol Interface

/// Unified interface for all transport mechanisms (BLE, WiFi Direct, future: LoRa, Ultrasonic)
protocol TransportProtocol: AnyObject {
    // MARK: - Properties
    var transportType: TransportType { get }
    var isAvailable: Bool { get }
    var isDiscovering: Bool { get }
    var currentPeers: [PeerInfo] { get }
    var delegate: TransportDelegate? { get set }
    
    // MARK: - Transport Capabilities
    var maxMessageSize: Int { get }
    var typicalThroughput: Int { get }  // bytes per second
    var powerConsumption: PowerLevel { get }
    var range: Int { get }  // meters
    
    // MARK: - Core Transport Operations
    func startDiscovery() throws
    func stopDiscovery()
    func send(_ packet: BitchatPacket, to peer: PeerID?) throws
    func connect(to peer: PeerInfo) throws
    func disconnect(from peer: PeerID)
    
    // MARK: - File Transfer Support
    func sendFile(_ data: Data, filename: String, to peer: PeerID, progress: @escaping (Double) -> Void) throws
    func canHandleFileSize(_ size: Int) -> Bool
    
    // MARK: - Transport Health
    func getConnectionQuality(for peer: PeerID) -> ConnectionQuality
    func getLatency(to peer: PeerID) -> TimeInterval?
}

// MARK: - Transport Types

enum TransportType: String, CaseIterable {
    case bluetooth = "bluetooth"
    case wifiDirect = "wifi-direct"
    case ultrasonic = "ultrasonic"  // Future enhancement
    case lora = "lora"              // Future enhancement
    
    var displayName: String {
        switch self {
        case .bluetooth: return "Bluetooth LE"
        case .wifiDirect: return "WiFi Direct"
        case .ultrasonic: return "Ultrasonic"
        case .lora: return "LoRa"
        }
    }
    
    var icon: String {
        switch self {
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .wifiDirect: return "wifi"
        case .ultrasonic: return "waveform"
        case .lora: return "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - Power and Performance Enums

enum PowerLevel: Int, Comparable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case high = 4
    case veryHigh = 5
    
    static func < (lhs: PowerLevel, rhs: PowerLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

enum ConnectionQuality: Int, Comparable {
    case poor = 1
    case fair = 2
    case good = 3
    case excellent = 4
    
    static func < (lhs: ConnectionQuality, rhs: ConnectionQuality) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var description: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

// MARK: - Peer Information

struct PeerInfo: Identifiable, Hashable {
    let id: String
    let nickname: String
    let transportType: TransportType
    let lastSeen: Date
    let connectionQuality: ConnectionQuality
    let supportedTransports: Set<TransportType>
    let publicKey: Data?
    
    // Convenience accessors
    var peerID: PeerID { return id }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(transportType)
    }
    
    static func == (lhs: PeerInfo, rhs: PeerInfo) -> Bool {
        return lhs.id == rhs.id && lhs.transportType == rhs.transportType
    }
}

// MARK: - Transport Delegate

protocol TransportDelegate: AnyObject {
    // Discovery events
    func transport(_ transport: TransportProtocol, didDiscoverPeer peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didLosePeer peer: PeerInfo)
    
    // Connection events
    func transport(_ transport: TransportProtocol, didConnectTo peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didDisconnectFrom peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didFailToConnect peer: PeerInfo, error: Error)
    
    // Message events
    func transport(_ transport: TransportProtocol, didReceivePacket packet: BitchatPacket, from peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didFailToSend packet: BitchatPacket, to peer: PeerInfo, error: Error)
    
    // File transfer events
    func transport(_ transport: TransportProtocol, didReceiveFileStart filename: String, size: Int, from peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didReceiveFileProgress progress: Double, for filename: String, from peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didReceiveFileComplete data: Data, filename: String, from peer: PeerInfo)
    func transport(_ transport: TransportProtocol, didFailFileTransfer filename: String, error: Error, from peer: PeerInfo)
    
    // Transport state changes
    func transport(_ transport: TransportProtocol, didChangeAvailability isAvailable: Bool)
    func transport(_ transport: TransportProtocol, didUpdateConnectionQuality quality: ConnectionQuality, for peer: PeerInfo)
}

// MARK: - Transport Errors

enum TransportError: LocalizedError {
    case transportUnavailable(TransportType)
    case peerNotFound(PeerID)
    case connectionFailed(String)
    case sendFailed(String)
    case fileTooLarge(Int, Int) // actual size, max size
    case encryptionFailed
    case timeout
    case invalidPeer
    case transportNotSupported
    
    var errorDescription: String? {
        switch self {
        case .transportUnavailable(let type):
            return "\(type.displayName) transport is not available"
        case .peerNotFound(let peerID):
            return "Peer \(peerID) not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .sendFailed(let reason):
            return "Send failed: \(reason)"
        case .fileTooLarge(let actual, let max):
            return "File size \(actual) bytes exceeds maximum \(max) bytes for this transport"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .timeout:
            return "Operation timed out"
        case .invalidPeer:
            return "Invalid peer information"
        case .transportNotSupported:
            return "Transport type not supported on this platform"
        }
    }
}

// MARK: - Transport Statistics

struct TransportStatistics {
    let transportType: TransportType
    let messagesSent: Int
    let messagesReceived: Int
    let bytesSent: Int64
    let bytesReceived: Int64
    let connectionsEstablished: Int
    let connectionFailures: Int
    let averageLatency: TimeInterval
    let averageThroughput: Double // bytes per second
    let lastActivity: Date?
    
    var successRate: Double {
        let total = connectionsEstablished + connectionFailures
        return total > 0 ? Double(connectionsEstablished) / Double(total) : 0.0
    }
}

// MARK: - Transport Capabilities

struct TransportCapabilities {
    let type: TransportType
    let maxMessageSize: Int
    let maxFileSize: Int64
    let supportsStreaming: Bool
    let supportsBroadcast: Bool
    let supportsEncryption: Bool
    let requiresDiscovery: Bool
    let batteryEfficient: Bool
    let range: Int // meters
    let typicalThroughput: Int // bytes per second
    
    static let bluetooth = TransportCapabilities(
        type: .bluetooth,
        maxMessageSize: 512,
        maxFileSize: 100_000_000, // 100MB
        supportsStreaming: false,
        supportsBroadcast: true,
        supportsEncryption: true,
        requiresDiscovery: true,
        batteryEfficient: true,
        range: 30,
        typicalThroughput: 2_000 // 2KB/s
    )
    
    static let wifiDirect = TransportCapabilities(
        type: .wifiDirect,
        maxMessageSize: 1_000_000, // 1MB
        maxFileSize: 10_000_000_000, // 10GB
        supportsStreaming: true,
        supportsBroadcast: false,
        supportsEncryption: true,
        requiresDiscovery: true,
        batteryEfficient: false,
        range: 200,
        typicalThroughput: 25_000_000 // 25MB/s
    )
}

// MARK: - Type Aliases

typealias PeerID = String