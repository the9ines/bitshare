//
// TransportDelegate.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation

// MARK: - Transport Delegate Extensions

/// Optional delegate methods with default implementations
extension TransportDelegate {
    // Default implementations for optional methods
    
    func transport(_ transport: TransportProtocol, didDiscoverPeer peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didLosePeer peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didConnectTo peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didDisconnectFrom peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didFailToConnect peer: PeerInfo, error: Error) {
        print("[Transport] Failed to connect to \(peer.nickname): \(error.localizedDescription)")
    }
    
    func transport(_ transport: TransportProtocol, didFailToSend packet: BitchatPacket, to peer: PeerInfo, error: Error) {
        print("[Transport] Failed to send packet to \(peer.nickname): \(error.localizedDescription)")
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileStart filename: String, size: Int, from peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileProgress progress: Double, for filename: String, from peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileComplete data: Data, filename: String, from peer: PeerInfo) {
        // Default: no-op
    }
    
    func transport(_ transport: TransportProtocol, didFailFileTransfer filename: String, error: Error, from peer: PeerInfo) {
        print("[Transport] File transfer failed for \(filename) from \(peer.nickname): \(error.localizedDescription)")
    }
    
    func transport(_ transport: TransportProtocol, didChangeAvailability isAvailable: Bool) {
        print("[Transport] \(transport.transportType.displayName) availability changed: \(isAvailable)")
    }
    
    func transport(_ transport: TransportProtocol, didUpdateConnectionQuality quality: ConnectionQuality, for peer: PeerInfo) {
        // Default: no-op - connection quality updates are frequent
    }
}

// MARK: - Transport Observer

/// Observer pattern for multiple listeners to transport events
class TransportObserver {
    private var delegates: [WeakTransportDelegate] = []
    
    func addDelegate(_ delegate: TransportDelegate) {
        // Remove any existing weak references to the same delegate
        removeDelegate(delegate)
        delegates.append(WeakTransportDelegate(delegate))
    }
    
    func removeDelegate(_ delegate: TransportDelegate) {
        delegates.removeAll { $0.delegate === delegate }
        // Also remove nil references
        delegates.removeAll { $0.delegate == nil }
    }
    
    // Forward all delegate methods to registered delegates
    func transport(_ transport: TransportProtocol, didDiscoverPeer peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didDiscoverPeer: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didLosePeer peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didLosePeer: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didConnectTo peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didConnectTo: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didDisconnectFrom peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didDisconnectFrom: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didFailToConnect peer: PeerInfo, error: Error) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didFailToConnect: peer, error: error) }
    }
    
    func transport(_ transport: TransportProtocol, didReceivePacket packet: BitchatPacket, from peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didReceivePacket: packet, from: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didFailToSend packet: BitchatPacket, to peer: PeerInfo, error: Error) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didFailToSend: packet, to: peer, error: error) }
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileStart filename: String, size: Int, from peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didReceiveFileStart: filename, size: size, from: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileProgress progress: Double, for filename: String, from peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didReceiveFileProgress: progress, for: filename, from: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileComplete data: Data, filename: String, from peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didReceiveFileComplete: data, filename: filename, from: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didFailFileTransfer filename: String, error: Error, from peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didFailFileTransfer: filename, error: error, from: peer) }
    }
    
    func transport(_ transport: TransportProtocol, didChangeAvailability isAvailable: Bool) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didChangeAvailability: isAvailable) }
    }
    
    func transport(_ transport: TransportProtocol, didUpdateConnectionQuality quality: ConnectionQuality, for peer: PeerInfo) {
        cleanupDelegates()
        delegates.forEach { $0.delegate?.transport(transport, didUpdateConnectionQuality: quality, for: peer) }
    }
    
    private func cleanupDelegates() {
        delegates.removeAll { $0.delegate == nil }
    }
}

// MARK: - Weak Delegate Wrapper

private class WeakTransportDelegate {
    weak var delegate: TransportDelegate?
    
    init(_ delegate: TransportDelegate) {
        self.delegate = delegate
    }
}

// MARK: - Transport Event Types

enum TransportEvent {
    case peerDiscovered(PeerInfo)
    case peerLost(PeerInfo)
    case connected(PeerInfo)
    case disconnected(PeerInfo)
    case connectionFailed(PeerInfo, Error)
    case packetReceived(BitchatPacket, PeerInfo)
    case sendFailed(BitchatPacket, PeerInfo, Error)
    case fileTransferStarted(String, Int, PeerInfo)
    case fileTransferProgress(Double, String, PeerInfo)
    case fileTransferComplete(Data, String, PeerInfo)
    case fileTransferFailed(String, Error, PeerInfo)
    case availabilityChanged(Bool)
    case connectionQualityUpdated(ConnectionQuality, PeerInfo)
}

// MARK: - Transport Event Handler

/// Closure-based event handling as an alternative to delegation
typealias TransportEventHandler = (TransportEvent) -> Void

extension TransportProtocol {
    /// Convenience method to set up closure-based event handling
    func setEventHandler(_ handler: @escaping TransportEventHandler) {
        let closureDelegate = ClosureTransportDelegate(handler: handler)
        self.delegate = closureDelegate
    }
}

private class ClosureTransportDelegate: TransportDelegate {
    private let eventHandler: TransportEventHandler
    
    init(handler: @escaping TransportEventHandler) {
        self.eventHandler = handler
    }
    
    func transport(_ transport: TransportProtocol, didDiscoverPeer peer: PeerInfo) {
        eventHandler(.peerDiscovered(peer))
    }
    
    func transport(_ transport: TransportProtocol, didLosePeer peer: PeerInfo) {
        eventHandler(.peerLost(peer))
    }
    
    func transport(_ transport: TransportProtocol, didConnectTo peer: PeerInfo) {
        eventHandler(.connected(peer))
    }
    
    func transport(_ transport: TransportProtocol, didDisconnectFrom peer: PeerInfo) {
        eventHandler(.disconnected(peer))
    }
    
    func transport(_ transport: TransportProtocol, didFailToConnect peer: PeerInfo, error: Error) {
        eventHandler(.connectionFailed(peer, error))
    }
    
    func transport(_ transport: TransportProtocol, didReceivePacket packet: BitchatPacket, from peer: PeerInfo) {
        eventHandler(.packetReceived(packet, peer))
    }
    
    func transport(_ transport: TransportProtocol, didFailToSend packet: BitchatPacket, to peer: PeerInfo, error: Error) {
        eventHandler(.sendFailed(packet, peer, error))
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileStart filename: String, size: Int, from peer: PeerInfo) {
        eventHandler(.fileTransferStarted(filename, size, peer))
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileProgress progress: Double, for filename: String, from peer: PeerInfo) {
        eventHandler(.fileTransferProgress(progress, filename, peer))
    }
    
    func transport(_ transport: TransportProtocol, didReceiveFileComplete data: Data, filename: String, from peer: PeerInfo) {
        eventHandler(.fileTransferComplete(data, filename, peer))
    }
    
    func transport(_ transport: TransportProtocol, didFailFileTransfer filename: String, error: Error, from peer: PeerInfo) {
        eventHandler(.fileTransferFailed(filename, error, peer))
    }
    
    func transport(_ transport: TransportProtocol, didChangeAvailability isAvailable: Bool) {
        eventHandler(.availabilityChanged(isAvailable))
    }
    
    func transport(_ transport: TransportProtocol, didUpdateConnectionQuality quality: ConnectionQuality, for peer: PeerInfo) {
        eventHandler(.connectionQualityUpdated(quality, peer))
    }
}