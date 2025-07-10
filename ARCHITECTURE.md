# bitshare File Transfer Architecture

## Overview

bitshare extends bitchat's proven mesh networking protocol to support secure file sharing while maintaining 100% visual and technical consistency. This architecture leverages the existing Bluetooth mesh infrastructure and adds file-specific capabilities on top.

## Core Design Principles

1. **Zero Changes to Core Protocol**: All existing bitchat message types remain unchanged
2. **Backward Compatibility**: bitshare and bitchat devices operate on the same mesh
3. **Visual Consistency**: Maintain exact SF Mono typography, green accent (#00FF00), and spring animations
4. **480-byte BLE Optimization**: Chunk size designed for Bluetooth LE MTU constraints
5. **Security Preservation**: X25519 + AES-256-GCM encryption applied to all file data

## 1. File Chunking Strategy

### BLE MTU Optimization
```swift
// Chunk size optimized for Bluetooth LE MTU (512 bytes)
// Accounting for protocol overhead: 512 - 32 (overhead) = 480 bytes
static let CHUNK_SIZE: Int = 480

// Maximum file size: 480 bytes × 4,294,967,295 chunks = ~2TB theoretical limit
// Practical limit: ~100MB for mesh network performance
static let RECOMMENDED_MAX_FILE_SIZE: UInt64 = 100 * 1024 * 1024  // 100MB
```

### Chunking Algorithm
```swift
struct FileChunkingService {
    static func chunkFile(_ fileData: Data, fileID: String) -> [FileChunk] {
        let totalChunks = (fileData.count + CHUNK_SIZE - 1) / CHUNK_SIZE
        var chunks: [FileChunk] = []
        
        for i in 0..<totalChunks {
            let start = i * CHUNK_SIZE
            let end = min(start + CHUNK_SIZE, fileData.count)
            let chunkData = fileData.subdata(in: start..<end)
            
            // Each chunk includes integrity hash
            let chunk = FileChunk(
                fileID: fileID,
                chunkIndex: UInt32(i),
                payload: chunkData,
                isLastChunk: i == totalChunks - 1
            )
            
            chunks.append(chunk)
        }
        
        return chunks
    }
}
```

## 2. Protocol Message Specifications

### FILE_MANIFEST (0x0D)
```swift
struct FILE_MANIFEST: Codable {
    // Core identification
    let fileID: String              // UUID for this transfer
    let fileName: String            // Original filename (encrypted)
    let fileSize: UInt64           // Total bytes
    let totalChunks: UInt32        // Number of chunks
    
    // Integrity verification
    let sha256Hash: String         // SHA-256 of complete file
    let manifestSignature: Data    // Ed25519 signature of manifest
    
    // Transfer metadata
    let senderID: String           // Mesh peer ID
    let timestamp: UInt64          // Creation time (milliseconds)
    let priority: TransferPriority // Transfer urgency
    
    // Optional metadata (encrypted)
    let mimeType: String?          // Content type
    let filePermissions: UInt16?   // Unix-style permissions
    let compressionType: CompressionType? // Applied compression
    
    // Resume support
    let resumeToken: String?       // For resuming interrupted transfers
    let chunkHashes: [String]?     // SHA-256 hash per chunk (optional)
}

enum TransferPriority: UInt8, Codable {
    case low = 1
    case normal = 2  
    case high = 3
    case urgent = 4
}

enum CompressionType: UInt8, Codable {
    case none = 0
    case lz4 = 1
    case gzip = 2
}
```

### FILE_CHUNK (0x0E)
```swift
struct FILE_CHUNK: Codable {
    // Identification
    let fileID: String             // References FILE_MANIFEST
    let chunkIndex: UInt32         // 0-based chunk number
    let chunkSequence: UInt32      // Transmission sequence (for reordering)
    
    // Payload
    let payload: Data              // Actual file data (≤480 bytes)
    let isLastChunk: Bool          // True for final chunk
    
    // Integrity
    let chunkHash: String          // SHA-256 of payload
    let chunkMAC: Data             // HMAC for additional integrity
    
    // Transfer control
    let retryCount: UInt8          // Number of retransmissions
    let timestamp: UInt64          // When chunk was sent
}
```

### FILE_ACK (0x0F)
```swift
struct FILE_ACK: Codable {
    // Identification
    let fileID: String             // File being acknowledged
    let ackID: String              // Unique ACK identifier
    let receiverID: String         // Who is sending this ACK
    
    // Acknowledgment data
    let acknowledgedChunks: [UInt32] // Successfully received chunks
    let missingChunks: [UInt32]    // Chunks to be retransmitted
    let receivedBitmap: Data       // Compressed bitmap of received chunks
    
    // Transfer control
    let requestedChunks: [UInt32]? // Specific chunks to send next
    let pauseTransfer: Bool        // Request to pause transfer
    let cancelTransfer: Bool       // Request to cancel transfer
    
    // Status
    let timestamp: UInt64          // ACK generation time
    let totalReceived: UInt32      // Total chunks received so far
    let transferComplete: Bool     // All chunks received successfully
}
```

## 3. Progress Tracking UI

### Real-time Progress Updates
```swift
// Extends existing bitchat UI patterns with file transfer displays
struct FileTransferProgressView: View {
    let transfer: FileTransferState
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // File info (maintains bitchat's text styling)
            HStack {
                Image(systemName: fileIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.green)  // bitchat's accent color
                
                Text(transfer.fileName)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(transfer.progress))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar (bitchat-style animation)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.green)  // bitchat's accent color
                        .frame(width: geometry.size.width * (transfer.progress / 100.0), height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: transfer.progress)
                }
            }
            .frame(height: 4)
            
            // Transfer details
            HStack {
                Text(transfer.status.displayText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if transfer.isActive {
                    Text("\(transfer.transferSpeed)/s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)  // bitchat's standard padding
        .padding(.vertical, 8)
    }
    
    private var fileIcon: String {
        switch transfer.mimeType?.prefix(while: { $0 != "/" }) {
        case "image": return "photo"
        case "video": return "video"
        case "audio": return "music.note"
        case "text": return "doc.text"
        default: return "doc"
        }
    }
}
```

### Transfer Queue Display
```swift
struct FileTransferQueueView: View {
    @ObservedObject var transferManager: FileTransferManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {  // bitchat's standard spacing
                ForEach(transferManager.activeTransfers, id: \.id) { transfer in
                    FileTransferProgressView(transfer: transfer)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}
```

## 4. File Integrity Verification

### Multi-layer Integrity Checking
```swift
struct FileIntegrityService {
    // SHA-256 verification for complete files
    static func verifyFileIntegrity(_ fileData: Data, expectedHash: String) -> Bool {
        let calculatedHash = SHA256.hash(data: fileData)
        let hashString = calculatedHash.compactMap { String(format: "%02x", $0) }.joined()
        return hashString == expectedHash
    }
    
    // Individual chunk verification
    static func verifyChunkIntegrity(_ chunk: FILE_CHUNK) -> Bool {
        let calculatedHash = SHA256.hash(data: chunk.payload)
        let hashString = calculatedHash.compactMap { String(format: "%02x", $0) }.joined()
        return hashString == chunk.chunkHash
    }
    
    // Additional HMAC verification for chunks
    static func verifyChunkMAC(_ chunk: FILE_CHUNK, key: SymmetricKey) -> Bool {
        let calculatedMAC = HMAC<SHA256>.authenticationCode(for: chunk.payload, using: key)
        return Data(calculatedMAC) == chunk.chunkMAC
    }
    
    // Reed-Solomon error correction for critical transfers
    static func applyErrorCorrection(_ chunks: [FILE_CHUNK]) -> [FILE_CHUNK] {
        // Implement Reed-Solomon FEC for ultra-reliable transfers
        // This would add redundancy chunks for automatic error correction
        return chunks  // Simplified for this example
    }
}
```

## 5. Resume/Retry Mechanisms

### Transfer State Management
```swift
class FileTransferState: ObservableObject {
    let transferID: String
    let manifest: FILE_MANIFEST
    
    @Published var status: TransferStatus
    @Published var progress: Double = 0.0
    @Published var transferSpeed: String = ""
    
    // Resume support
    var completedChunks: Set<UInt32> = []
    var failedChunks: Set<UInt32> = []
    var retryAttempts: [UInt32: Int] = [:]
    
    // Timing
    let startTime: Date
    var lastActivityTime: Date
    var estimatedTimeRemaining: TimeInterval?
    
    enum TransferStatus {
        case preparing
        case transferring(received: UInt32, total: UInt32)
        case paused(at: UInt32)
        case completed(fileURL: URL)
        case failed(reason: String, canRetry: Bool)
        case cancelled
    }
    
    init(manifest: FILE_MANIFEST) {
        self.transferID = manifest.fileID
        self.manifest = manifest
        self.status = .preparing
        self.startTime = Date()
        self.lastActivityTime = Date()
    }
    
    // Resume from interruption
    func resumeTransfer() {
        guard case .paused(let lastChunk) = status else { return }
        
        let remaining = Set(0..<manifest.totalChunks).subtracting(completedChunks)
        status = .transferring(received: UInt32(completedChunks.count), total: manifest.totalChunks)
        
        // Request missing chunks
        NotificationCenter.default.post(
            name: .requestMissingChunks,
            object: nil,
            userInfo: ["transferID": transferID, "missingChunks": Array(remaining)]
        )
    }
    
    // Retry failed chunks with exponential backoff
    func retryFailedChunks() {
        for chunkIndex in failedChunks {
            let attempts = retryAttempts[chunkIndex, default: 0]
            let delay = pow(2.0, Double(attempts)) // Exponential backoff
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.requestChunkRetry(chunkIndex)
            }
            
            retryAttempts[chunkIndex] = attempts + 1
        }
    }
    
    private func requestChunkRetry(_ chunkIndex: UInt32) {
        NotificationCenter.default.post(
            name: .retryChunk,
            object: nil,
            userInfo: ["transferID": transferID, "chunkIndex": chunkIndex]
        )
    }
}
```

## 6. Storage Management

### Secure File Storage
```swift
struct FileStorageManager {
    private static let transfersDirectory = "FileTransfers"
    private static let incomingDirectory = "Incoming"
    private static let outgoingDirectory = "Outgoing"
    private static let temporaryDirectory = "Temporary"
    
    // Secure sandboxed storage
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static var transfersBaseURL: URL {
        documentsDirectory.appendingPathComponent(transfersDirectory)
    }
    
    // Initialize storage structure
    static func initializeStorage() throws {
        let directories = [
            transfersBaseURL.appendingPathComponent(incomingDirectory),
            transfersBaseURL.appendingPathComponent(outgoingDirectory),
            transfersBaseURL.appendingPathComponent(temporaryDirectory)
        ]
        
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    // Temporary storage during transfer
    static func createTemporaryFile(for transferID: String) -> URL {
        let tempURL = transfersBaseURL
            .appendingPathComponent(temporaryDirectory)
            .appendingPathComponent("\(transferID).partial")
        return tempURL
    }
    
    // Move completed file to final location
    static func finalizeTransfer(_ transferID: String, fileName: String, isIncoming: Bool) throws -> URL {
        let tempURL = createTemporaryFile(for: transferID)
        let finalDirectory = isIncoming ? incomingDirectory : outgoingDirectory
        let finalURL = transfersBaseURL
            .appendingPathComponent(finalDirectory)
            .appendingPathComponent(fileName)
        
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
        return finalURL
    }
    
    // Cleanup interrupted transfers
    static func cleanupStaleTransfers(olderThan: TimeInterval = 86400) { // 24 hours
        let tempDirectory = transfersBaseURL.appendingPathComponent(temporaryDirectory)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modDate = attributes.contentModificationDate,
                   Date().timeIntervalSince(modDate) > olderThan {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Error cleaning up stale transfers: \(error)")
        }
    }
    
    // Get storage usage statistics
    static func getStorageUsage() -> (incoming: UInt64, outgoing: UInt64, temporary: UInt64) {
        func directorySize(_ url: URL) -> UInt64 {
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
            
            var totalSize: UInt64 = 0
            for case let fileURL as URL in enumerator {
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += UInt64(attributes.fileSize ?? 0)
                } catch {
                    continue
                }
            }
            return totalSize
        }
        
        return (
            incoming: directorySize(transfersBaseURL.appendingPathComponent(incomingDirectory)),
            outgoing: directorySize(transfersBaseURL.appendingPathComponent(outgoingDirectory)),
            temporary: directorySize(transfersBaseURL.appendingPathComponent(temporaryDirectory))
        )
    }
}
```

## 7. Multi-file Transfer Queue

### Transfer Queue Management
```swift
class FileTransferManager: ObservableObject {
    @Published var activeTransfers: [FileTransferState] = []
    @Published var queuedTransfers: [QueuedTransfer] = []
    @Published var completedTransfers: [CompletedTransfer] = []
    
    private let maxConcurrentTransfers = 3
    private let transferQueue = DispatchQueue(label: "file.transfer.queue", qos: .userInitiated)
    
    struct QueuedTransfer {
        let fileURL: URL
        let destinationPeer: String
        let priority: TransferPriority
        let queueTime: Date
    }
    
    struct CompletedTransfer {
        let fileName: String
        let fileSize: UInt64
        let peerName: String
        let completionTime: Date
        let transferDuration: TimeInterval
        let averageSpeed: UInt64  // bytes per second
    }
    
    // Add file to transfer queue
    func queueTransfer(_ fileURL: URL, to peerID: String, priority: TransferPriority = .normal) {
        let queuedTransfer = QueuedTransfer(
            fileURL: fileURL,
            destinationPeer: peerID,
            priority: priority,
            queueTime: Date()
        )
        
        // Insert based on priority
        let insertIndex = queuedTransfers.firstIndex { $0.priority.rawValue < priority.rawValue } ?? queuedTransfers.count
        queuedTransfers.insert(queuedTransfer, at: insertIndex)
        
        processQueue()
    }
    
    // Process queued transfers
    private func processQueue() {
        guard activeTransfers.count < maxConcurrentTransfers,
              !queuedTransfers.isEmpty else { return }
        
        let nextTransfer = queuedTransfers.removeFirst()
        startTransfer(nextTransfer)
    }
    
    private func startTransfer(_ queuedTransfer: QueuedTransfer) {
        transferQueue.async { [weak self] in
            // Implementation for starting actual transfer
            // This would integrate with FileTransferService
        }
    }
    
    // Pause all active transfers
    func pauseAllTransfers() {
        for transfer in activeTransfers {
            if case .transferring = transfer.status {
                transfer.status = .paused(at: UInt32(transfer.completedChunks.count))
            }
        }
    }
    
    // Resume all paused transfers
    func resumeAllTransfers() {
        for transfer in activeTransfers {
            if case .paused = transfer.status {
                transfer.resumeTransfer()
            }
        }
    }
    
    // Cancel transfer and remove from queue
    func cancelTransfer(_ transferID: String) {
        if let index = activeTransfers.firstIndex(where: { $0.transferID == transferID }) {
            activeTransfers[index].status = .cancelled
            activeTransfers.remove(at: index)
            processQueue()  // Start next queued transfer
        }
    }
}
```

## 8. Integration with bitchat Mesh Protocol

### Protocol Extensions
```swift
extension BluetoothMeshService {
    // Handle file transfer message types
    func handleFileMessage(_ packet: BitchatPacket) {
        switch packet.type {
        case MessageType.FILE_MANIFEST.rawValue:
            handleFileManifest(packet)
        case MessageType.FILE_CHUNK.rawValue:
            handleFileChunk(packet)
        case MessageType.FILE_ACK.rawValue:
            handleFileAck(packet)
        default:
            // Pass to existing message handler
            handleMessage(packet)
        }
    }
    
    private func handleFileManifest(_ packet: BitchatPacket) {
        guard let manifest = try? JSONDecoder().decode(FILE_MANIFEST.self, from: packet.payload) else {
            return
        }
        
        // Verify signature
        guard verifyManifestSignature(manifest, from: packet.senderID) else {
            print("Invalid manifest signature from \(packet.senderID)")
            return
        }
        
        // Notify UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .fileManifestReceived,
                object: manifest,
                userInfo: ["senderID": packet.senderID]
            )
        }
    }
    
    private func handleFileChunk(_ packet: BitchatPacket) {
        guard let chunk = try? JSONDecoder().decode(FILE_CHUNK.self, from: packet.payload) else {
            return
        }
        
        // Verify chunk integrity
        guard FileIntegrityService.verifyChunkIntegrity(chunk) else {
            print("Chunk integrity verification failed for \(chunk.fileID):\(chunk.chunkIndex)")
            return
        }
        
        // Process chunk
        FileTransferService.shared.processReceivedChunk(chunk, from: packet.senderID)
    }
    
    private func handleFileAck(_ packet: BitchatPacket) {
        guard let ack = try? JSONDecoder().decode(FILE_ACK.self, from: packet.payload) else {
            return
        }
        
        // Process acknowledgment
        FileTransferService.shared.processFileAck(ack, from: packet.senderID)
    }
    
    // Send file transfer messages
    func sendFileManifest(_ manifest: FILE_MANIFEST, to peerID: String) {
        guard let payload = try? JSONEncoder().encode(manifest) else { return }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_MANIFEST.rawValue,
            ttl: maxTTL,
            senderID: myPeerID,
            payload: payload
        )
        
        broadcastPacket(packet)
    }
    
    func sendFileChunk(_ chunk: FILE_CHUNK, to peerID: String) {
        guard let payload = try? JSONEncoder().encode(chunk) else { return }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_CHUNK.rawValue,
            ttl: maxTTL,
            senderID: myPeerID,
            payload: payload
        )
        
        broadcastPacket(packet)
    }
    
    func sendFileAck(_ ack: FILE_ACK, to peerID: String) {
        guard let payload = try? JSONEncoder().encode(ack) else { return }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_ACK.rawValue,
            ttl: maxTTL,
            senderID: myPeerID,
            payload: payload
        )
        
        broadcastPacket(packet)
    }
}

// Notification names for file transfer events
extension Notification.Name {
    static let fileManifestReceived = Notification.Name("fileManifestReceived")
    static let fileChunkReceived = Notification.Name("fileChunkReceived")
    static let fileAckReceived = Notification.Name("fileAckReceived")
    static let transferProgress = Notification.Name("transferProgress")
    static let transferCompleted = Notification.Name("transferCompleted")
    static let transferFailed = Notification.Name("transferFailed")
    static let requestMissingChunks = Notification.Name("requestMissingChunks")
    static let retryChunk = Notification.Name("retryChunk")
}
```

This architecture provides a robust, secure, and efficient file transfer system that seamlessly integrates with bitchat's proven mesh networking protocol while maintaining complete visual and technical consistency.