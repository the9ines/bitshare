//
// BluetoothTransport.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Bluetooth Transport Wrapper

/// Transport wrapper for existing BluetoothMeshService
/// Maintains 100% backward compatibility while adding transport abstraction
class BluetoothTransport: NSObject, TransportProtocol {
    
    // MARK: - TransportProtocol Properties
    
    let transportType: TransportType = .bluetooth
    
    var isAvailable: Bool {
        return meshService.centralManager?.state == .poweredOn || 
               meshService.peripheralManager?.state == .poweredOn
    }
    
    var isDiscovering: Bool {
        return meshService.isAdvertising || meshService.isScanning
    }
    
    private(set) var currentPeers: [PeerInfo] = []
    
    weak var delegate: TransportDelegate?
    
    // Transport capabilities for Bluetooth LE
    let maxMessageSize: Int = 512  // BLE MTU limitation
    let typicalThroughput: Int = 2_000  // 2KB/s typical for BLE
    let powerConsumption: PowerLevel = .low
    let range: Int = 30  // 30 meters
    
    // MARK: - Private Properties
    
    private let meshService: BluetoothMeshService
    private var cancellables = Set<AnyCancellable>()
    private var peerInfoCache: [String: PeerInfo] = [:]
    private var fileTransfers: [String: FileTransferSession] = [:]
    
    // Statistics tracking
    private var messagesSent: Int = 0
    private var messagesReceived: Int = 0
    private var bytesSent: Int64 = 0
    private var bytesReceived: Int64 = 0
    private var lastActivity: Date?
    
    // MARK: - Initialization
    
    init(meshService: BluetoothMeshService) {
        self.meshService = meshService
        super.init()
        
        setupMeshServiceIntegration()
        print("[BluetoothTransport] Initialized with existing BluetoothMeshService")
    }
    
    // MARK: - TransportProtocol Implementation
    
    func startDiscovery() throws {
        guard isAvailable else {
            throw TransportError.transportUnavailable(.bluetooth)
        }
        
        // Use existing mesh service discovery
        meshService.startAdvertising()
        meshService.startScanning()
        
        print("[BluetoothTransport] Started discovery")
        delegate?.transport(self, didChangeAvailability: true)
    }
    
    func stopDiscovery() {
        meshService.stopAdvertising()
        meshService.stopScanning()
        
        currentPeers.removeAll()
        peerInfoCache.removeAll()
        
        print("[BluetoothTransport] Stopped discovery")
        delegate?.transport(self, didChangeAvailability: false)
    }
    
    func send(_ packet: BitchatPacket, to peer: PeerID?) throws {
        guard packet.payload.count <= maxMessageSize else {
            throw TransportError.fileTooLarge(packet.payload.count, maxMessageSize)
        }
        
        // Use existing mesh service broadcast functionality
        if let peerID = peer {
            // Direct message to specific peer
            meshService.sendPrivateMessage(
                String(data: packet.payload, encoding: .utf8) ?? "",
                to: peerID,
                recipientNickname: getNickname(for: peerID)
            )
        } else {
            // Broadcast message
            meshService.sendMessage(
                String(data: packet.payload, encoding: .utf8) ?? ""
            )
        }
        
        messagesSent += 1
        bytesSent += Int64(packet.payload.count)
        lastActivity = Date()
        
        print("[BluetoothTransport] Sent packet (\(packet.payload.count) bytes) to \(peer ?? "broadcast")")
    }
    
    func connect(to peer: PeerInfo) throws {
        // Bluetooth mesh connections are handled automatically
        // Just verify the peer is available
        guard currentPeers.contains(where: { $0.id == peer.id }) else {
            throw TransportError.peerNotFound(peer.id)
        }
        
        print("[BluetoothTransport] Connection request for \(peer.nickname) - handled by mesh service")
    }
    
    func disconnect(from peer: PeerID) {
        // Remove from current peers (mesh service handles actual disconnection)
        currentPeers.removeAll { $0.id == peer }
        peerInfoCache.removeValue(forKey: peer)
        
        print("[BluetoothTransport] Disconnected from \(peer)")
    }
    
    func sendFile(_ data: Data, filename: String, to peer: PeerID, progress: @escaping (Double) -> Void) throws {
        guard data.count <= Int(TransportCapabilities.bluetooth.maxFileSize) else {
            throw TransportError.fileTooLarge(data.count, Int(TransportCapabilities.bluetooth.maxFileSize))
        }
        
        guard let peerInfo = currentPeers.first(where: { $0.id == peer }) else {
            throw TransportError.peerNotFound(peer)
        }
        
        let transferID = UUID().uuidString
        let session = FileTransferSession(
            id: transferID,
            filename: filename,
            data: data,
            peer: peer,
            progress: progress
        )
        
        fileTransfers[transferID] = session
        
        // Notify delegate of transfer start
        delegate?.transport(
            self,
            didReceiveFileStart: filename,
            size: data.count,
            from: peerInfo
        )
        
        // Start chunked file transfer using existing mesh service
        startChunkedFileTransfer(session: session)
        
        print("[BluetoothTransport] Started file transfer: \(filename) (\(data.count) bytes) to \(peer)")
    }
    
    func canHandleFileSize(_ size: Int) -> Bool {
        return size <= Int(TransportCapabilities.bluetooth.maxFileSize)
    }
    
    func getConnectionQuality(for peer: PeerID) -> ConnectionQuality {
        // Use RSSI and connection stability from mesh service
        let rssi = meshService.peerRSSI[peer]?.intValue ?? -80
        
        switch rssi {
        case -50...0: return .excellent
        case -65...(-51): return .good
        case -80...(-66): return .fair
        default: return .poor
        }
    }
    
    func getLatency(to peer: PeerID) -> TimeInterval? {
        // Bluetooth LE typical latency
        return 0.1  // 100ms typical for BLE
    }
    
    // MARK: - Private Methods
    
    private func setupMeshServiceIntegration() {
        // Monitor mesh service state changes
        // Note: BluetoothMeshService doesn't use Combine, so we'll monitor manually
        
        // Set up periodic peer updates
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentPeers()
        }
        
        print("[BluetoothTransport] Set up mesh service integration")
    }
    
    private func updateCurrentPeers() {
        // Get current peers from mesh service
        let activePeerIDs = meshService.getAllConnectedPeerIDs()
        var updatedPeers: [PeerInfo] = []
        
        for peerID in activePeerIDs {
            // Check if we already have this peer
            if let existingPeer = peerInfoCache[peerID] {
                updatedPeers.append(existingPeer)
                continue
            }
            
            // Create new peer info
            let nickname = meshService.peerNicknames[peerID] ?? "peer-\(peerID.prefix(4))"
            let rssi = meshService.peerRSSI[peerID]?.intValue ?? -80
            let quality = getConnectionQualityFromRSSI(rssi)
            
            let peerInfo = PeerInfo(
                id: peerID,
                nickname: nickname,
                transportType: .bluetooth,
                lastSeen: Date(),
                connectionQuality: quality,
                supportedTransports: [.bluetooth],  // BLE-only devices only support Bluetooth
                publicKey: meshService.encryptionService.getPeerIdentityKey(peerID)
            )
            
            peerInfoCache[peerID] = peerInfo
            updatedPeers.append(peerInfo)
            
            // Notify delegate of new peer
            delegate?.transport(self, didDiscoverPeer: peerInfo)
        }
        
        // Check for lost peers
        let lostPeers = currentPeers.filter { peer in
            !activePeerIDs.contains(peer.id)
        }
        
        for lostPeer in lostPeers {
            peerInfoCache.removeValue(forKey: lostPeer.id)
            delegate?.transport(self, didLosePeer: lostPeer)
        }
        
        currentPeers = updatedPeers
    }
    
    private func getConnectionQualityFromRSSI(_ rssi: Int) -> ConnectionQuality {
        switch rssi {
        case -50...0: return .excellent
        case -65...(-51): return .good
        case -80...(-66): return .fair
        default: return .poor
        }
    }
    
    private func getNickname(for peerID: PeerID) -> String {
        return meshService.peerNicknames[peerID] ?? "peer-\(peerID.prefix(4))"
    }
    
    private func startChunkedFileTransfer(session: FileTransferSession) {
        let chunkSize = 400  // BLE-safe chunk size
        let totalChunks = (session.data.count + chunkSize - 1) / chunkSize
        
        // Send file manifest first
        let manifest = [
            "type": "file_manifest",
            "transferID": session.id,
            "filename": session.filename,
            "totalSize": session.data.count,
            "totalChunks": totalChunks
        ]
        
        if let manifestData = try? JSONSerialization.data(withJSONObject: manifest) {
            let packet = BitchatPacket(
                type: MessageType.message.rawValue,
                payload: manifestData,
                senderID: meshService.myPeerID.data(using: .utf8) ?? Data(),
                timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                ttl: 3
            )
            
            try? send(packet, to: session.peer)
        }
        
        // Send chunks with progress updates
        DispatchQueue.global(qos: .userInitiated).async {
            for chunkIndex in 0..<totalChunks {
                let startOffset = chunkIndex * chunkSize
                let endOffset = min(startOffset + chunkSize, session.data.count)
                let chunkData = session.data.subdata(in: startOffset..<endOffset)
                
                let chunk = [
                    "type": "file_chunk",
                    "transferID": session.id,
                    "chunkIndex": chunkIndex,
                    "data": chunkData.base64EncodedString()
                ]
                
                if let chunkDataPacket = try? JSONSerialization.data(withJSONObject: chunk) {
                    let packet = BitchatPacket(
                        type: MessageType.message.rawValue,
                        payload: chunkDataPacket,
                        senderID: self.meshService.myPeerID.data(using: .utf8) ?? Data(),
                        timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                        ttl: 3
                    )
                    
                    try? self.send(packet, to: session.peer)
                }
                
                // Update progress
                let progress = Double(chunkIndex + 1) / Double(totalChunks)
                DispatchQueue.main.async {
                    session.progress(progress)
                    
                    if let peerInfo = self.currentPeers.first(where: { $0.id == session.peer }) {
                        self.delegate?.transport(
                            self,
                            didReceiveFileProgress: progress,
                            for: session.filename,
                            from: peerInfo
                        )
                    }
                }
                
                // Small delay between chunks to avoid overwhelming BLE
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            // Transfer complete
            DispatchQueue.main.async {
                if let peerInfo = self.currentPeers.first(where: { $0.id == session.peer }) {
                    self.delegate?.transport(
                        self,
                        didReceiveFileComplete: session.data,
                        filename: session.filename,
                        from: peerInfo
                    )
                }
                
                self.fileTransfers.removeValue(forKey: session.id)
            }
        }
    }
}

// MARK: - File Transfer Session

private class FileTransferSession {
    let id: String
    let filename: String
    let data: Data
    let peer: PeerID
    let progress: (Double) -> Void
    let startTime: Date = Date()
    
    init(id: String, filename: String, data: Data, peer: PeerID, progress: @escaping (Double) -> Void) {
        self.id = id
        self.filename = filename
        self.data = data
        self.peer = peer
        self.progress = progress
    }
}

// MARK: - BluetoothMeshService Extensions

extension BluetoothMeshService {
    
    /// Get all currently connected peer IDs
    func getAllConnectedPeerIDs() -> [String] {
        activePeersLock.lock()
        let peersCopy = Array(activePeers)
        activePeersLock.unlock()
        
        return peersCopy.filter { peerID in
            !peerID.isEmpty && peerID != "unknown" && peerID != myPeerID
        }
    }
    
    /// Check if mesh service is currently scanning
    var isScanning: Bool {
        return centralManager?.isScanning ?? false
    }
    
    /// Check if mesh service is currently advertising
    var isAdvertising: Bool {
        return peripheralManager?.isAdvertising ?? false
    }
}

// MARK: - Transport Statistics Extension

extension BluetoothTransport {
    
    var statistics: TransportStatistics {
        return TransportStatistics(
            transportType: .bluetooth,
            messagesSent: messagesSent,
            messagesReceived: messagesReceived,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            connectionsEstablished: currentPeers.count,
            connectionFailures: 0,  // TODO: Track failures
            averageLatency: 0.1,  // BLE typical latency
            averageThroughput: Double(typicalThroughput),
            lastActivity: lastActivity
        )
    }
}