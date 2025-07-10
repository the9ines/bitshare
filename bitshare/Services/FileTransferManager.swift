//
// FileTransferManager.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import SwiftUI
import Combine
import CryptoKit

// MARK: - Comprehensive File Transfer Management System

/// Central coordinator for all file transfer operations, maintaining bitchat's visual consistency
class FileTransferManager: ObservableObject {
    static let shared = FileTransferManager()
    
    // MARK: - Published Properties (for SwiftUI reactive updates)
    @Published var activeTransfers: [FileTransferState] = []
    @Published var queuedTransfers: [QueuedTransfer] = []
    @Published var completedTransfers: [CompletedTransfer] = []
    @Published var transferHistory: [TransferRecord] = []
    
    // Real-time progress tracking
    @Published var globalProgress: Double = 0.0
    @Published var totalBytesTransferred: UInt64 = 0
    @Published var currentTransferSpeed: UInt64 = 0  // bytes per second
    
    // UI state
    @Published var isTransferring: Bool = false
    @Published var showTransferQueue: Bool = false
    @Published var showCompletedTransfers: Bool = false
    
    // MARK: - Private Properties
    private var meshService: BluetoothMeshService?
    private let encryptionService = EncryptionService()
    private let maxConcurrentTransfers = 3
    private let transferQueue = DispatchQueue(label: "bitshare.fileTransfer", qos: .userInitiated)
    private let progressUpdateQueue = DispatchQueue(label: "bitshare.progress", qos: .userInitiated)
    
    // Performance monitoring
    private var transferStartTimes: [String: Date] = [:]
    private var lastProgressUpdate: Date = Date()
    private var bytesTransferredSinceLastUpdate: UInt64 = 0
    
    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    
    private init() {
        setupPerformanceMonitoring()
        setupNotificationHandlers()
        initializeStorageDirectories()
    }
    
    // MARK: - Public API
    
    /// Set the mesh service for network operations
    func setMeshService(_ meshService: BluetoothMeshService) {
        self.meshService = meshService
        setupMeshServiceIntegration()
    }
    
    /// Queue a file for transfer with drag-and-drop support
    func queueFileTransfer(_ fileURL: URL, to peerID: String, peerNickname: String, priority: TransferPriority = .normal) -> String? {
        do {
            // Validate file
            guard fileURL.startAccessingSecurityScopedResource() else {
                print("Cannot access file: \(fileURL.path)")
                return nil
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            let fileData = try Data(contentsOf: fileURL)
            guard fileData.count <= FileTransferConstants.RECOMMENDED_MAX_FILE_SIZE else {
                print("File too large: \(fileData.count) bytes")
                return nil
            }
            
            // Create transfer
            let transferID = UUID().uuidString
            let fileHash = SHA256.hash(data: fileData).compactMap { String(format: "%02x", $0) }.joined()
            
            let manifest = FILE_MANIFEST(
                fileID: transferID,
                fileName: fileURL.lastPathComponent,
                fileSize: UInt64(fileData.count),
                sha256Hash: fileHash,
                senderID: meshService?.myPeerID ?? "unknown"
            )
            
            let queuedTransfer = QueuedTransfer(
                transferID: transferID,
                fileURL: fileURL,
                manifest: manifest,
                peerID: peerID,
                peerNickname: peerNickname,
                priority: priority,
                queueTime: Date()
            )
            
            // Insert based on priority (high priority first)
            let insertIndex = queuedTransfers.firstIndex { $0.priority.rawValue < priority.rawValue } ?? queuedTransfers.count
            queuedTransfers.insert(queuedTransfer, at: insertIndex)
            
            // Add to transfer history immediately
            let historyRecord = TransferRecord(
                transferID: transferID,
                fileName: fileURL.lastPathComponent,
                fileSize: UInt64(fileData.count),
                senderReceiver: peerNickname,
                direction: .send,
                status: .preparing,
                timestamp: Date(),
                lastUpdated: Date()
            )
            transferHistory.insert(historyRecord, at: 0)
            
            processTransferQueue()
            return transferID
            
        } catch {
            print("Error preparing file transfer: \(error)")
            return nil
        }
    }
    
    /// Handle incoming file manifest from mesh network
    func handleIncomingManifest(_ manifest: FILE_MANIFEST, from peerID: String, peerNickname: String) {
        // Create incoming transfer state
        let transferState = FileTransferState(
            transferID: manifest.fileID,
            manifest: manifest,
            direction: .receive,
            peerID: peerID,
            peerNickname: peerNickname
        )
        
        activeTransfers.append(transferState)
        
        // Add to history
        let historyRecord = TransferRecord(
            transferID: manifest.fileID,
            fileName: manifest.fileName,
            fileSize: manifest.fileSize,
            senderReceiver: peerNickname,
            direction: .receive,
            status: .transferring(chunksReceived: 0, totalChunks: manifest.totalChunks),
            timestamp: Date(),
            lastUpdated: Date()
        )
        transferHistory.insert(historyRecord, at: 0)
        
        // Send ACK to confirm we're ready to receive
        sendInitialAck(for: manifest, to: peerID)
        
        print("📁 Incoming file: \(manifest.fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(manifest.fileSize), countStyle: .file))) from \(peerNickname)")
    }
    
    /// Process received file chunk
    func handleIncomingChunk(_ chunk: FILE_CHUNK, from peerID: String) {
        guard let transferState = activeTransfers.first(where: { $0.transferID == chunk.fileID }) else {
            print("⚠️ Received chunk for unknown transfer: \(chunk.fileID)")
            return
        }
        
        // Verify chunk integrity
        guard verifyChunkIntegrity(chunk) else {
            print("⚠️ Chunk integrity verification failed: \(chunk.fileID):\(chunk.chunkIndex)")
            requestChunkRetry(chunk.fileID, chunkIndex: chunk.chunkIndex, to: peerID)
            return
        }
        
        // Store chunk
        transferState.receivedChunks[chunk.chunkIndex] = chunk.payload
        transferState.completedChunks.insert(chunk.chunkIndex)
        
        // Update progress
        let progress = Double(transferState.completedChunks.count) / Double(transferState.manifest.totalChunks)
        transferState.progress = progress * 100.0
        updateGlobalProgress()
        
        // Send ACK
        sendChunkAck(for: chunk, to: peerID)
        
        // Check if transfer is complete
        if transferState.completedChunks.count == transferState.manifest.totalChunks {
            completeFileReceive(transferState)
        }
        
        // Update transfer status
        transferState.status = .transferring(
            chunksReceived: UInt32(transferState.completedChunks.count),
            totalChunks: transferState.manifest.totalChunks
        )
        updateTransferInHistory(transferState.transferID, status: transferState.status)
    }
    
    /// Handle file acknowledgment from peer
    func handleFileAck(_ ack: FILE_ACK, from peerID: String) {
        guard let transferState = activeTransfers.first(where: { $0.transferID == ack.fileID }) else {
            return
        }
        
        // Update acknowledged chunks
        transferState.ackedChunks.formUnion(ack.acknowledgedChunks)
        
        // Handle flow control
        if ack.pauseTransfer {
            pauseTransfer(ack.fileID)
        } else if ack.cancelTransfer {
            cancelTransfer(ack.fileID)
        } else if !ack.missingChunks.isEmpty {
            // Retransmit missing chunks
            retransmitChunks(Array(ack.missingChunks), for: ack.fileID, to: peerID)
        }
        
        // Update progress
        let progress = Double(transferState.ackedChunks.count) / Double(transferState.manifest.totalChunks)
        transferState.progress = progress * 100.0
        updateGlobalProgress()
        
        // Check completion
        if ack.transferComplete {
            completeFileTransfer(transferState)
        }
    }
    
    /// Pause active transfer
    func pauseTransfer(_ transferID: String) {
        guard let transferState = activeTransfers.first(where: { $0.transferID == transferID }) else {
            return
        }
        
        transferState.status = .paused(at: UInt32(transferState.completedChunks.count))
        updateTransferInHistory(transferID, status: transferState.status)
    }
    
    /// Resume paused transfer
    func resumeTransfer(_ transferID: String) {
        guard let transferState = activeTransfers.first(where: { $0.transferID == transferID }),
              case .paused = transferState.status else {
            return
        }
        
        if transferState.direction == .send {
            resumeSendingChunks(transferState)
        }
        
        transferState.status = .transferring(
            chunksReceived: UInt32(transferState.completedChunks.count),
            totalChunks: transferState.manifest.totalChunks
        )
        updateTransferInHistory(transferID, status: transferState.status)
    }
    
    /// Cancel transfer and cleanup
    func cancelTransfer(_ transferID: String) {
        // Remove from active transfers
        if let index = activeTransfers.firstIndex(where: { $0.transferID == transferID }) {
            let transferState = activeTransfers[index]
            transferState.status = .cancelled
            updateTransferInHistory(transferID, status: .cancelled)
            
            // Cleanup temporary files
            cleanupTransferFiles(transferID)
            
            activeTransfers.remove(at: index)
        }
        
        // Remove from queue
        queuedTransfers.removeAll { $0.transferID == transferID }
        
        // Process next queued transfer
        processTransferQueue()
        updateGlobalProgress()
    }
    
    /// Retry failed transfer
    func retryTransfer(_ transferID: String) {
        guard let historyRecord = transferHistory.first(where: { $0.transferID == transferID }),
              historyRecord.canRetry else {
            return
        }
        
        // Create new transfer with retry flag
        if historyRecord.direction == .send {
            // Re-queue the transfer
            // Note: This would need access to the original file URL
            print("Retrying send transfer: \(historyRecord.fileName)")
        } else {
            // Request retransmission from sender
            print("Requesting retransmission: \(historyRecord.fileName)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func processTransferQueue() {
        guard activeTransfers.count < maxConcurrentTransfers,
              !queuedTransfers.isEmpty else {
            return
        }
        
        let nextTransfer = queuedTransfers.removeFirst()
        startFileTransfer(nextTransfer)
    }
    
    private func startFileTransfer(_ queuedTransfer: QueuedTransfer) {
        transferQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Read file data
                let fileData = try Data(contentsOf: queuedTransfer.fileURL)
                
                // Create transfer state
                let transferState = FileTransferState(
                    transferID: queuedTransfer.transferID,
                    manifest: queuedTransfer.manifest,
                    direction: .send,
                    peerID: queuedTransfer.peerID,
                    peerNickname: queuedTransfer.peerNickname
                )
                transferState.fileData = fileData
                
                DispatchQueue.main.async {
                    self.activeTransfers.append(transferState)
                    self.transferStartTimes[transferState.transferID] = Date()
                }
                
                // Send manifest
                self.sendFileManifest(queuedTransfer.manifest, to: queuedTransfer.peerID)
                
                // Start sending chunks after brief delay for manifest processing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startSendingChunks(transferState)
                }
                
            } catch {
                print("Error starting file transfer: \(error)")
                DispatchQueue.main.async {
                    self.processTransferQueue()
                }
            }
        }
    }
    
    private func startSendingChunks(_ transferState: FileTransferState) {
        guard let fileData = transferState.fileData else { return }
        
        let chunks = createFileChunks(fileData, fileID: transferState.transferID)
        transferState.totalChunks = chunks
        
        transferQueue.async { [weak self] in
            for (index, chunk) in chunks.enumerated() {
                // Check if transfer is still active
                guard transferState.status != .cancelled,
                      transferState.status != .paused else {
                    break
                }
                
                // Rate limiting to avoid overwhelming mesh network
                if index > 0 {
                    Thread.sleep(forTimeInterval: 0.1) // 100ms between chunks
                }
                
                self?.sendFileChunk(chunk, to: transferState.peerID)
                
                // Update progress
                DispatchQueue.main.async {
                    let progress = Double(index + 1) / Double(chunks.count)
                    transferState.progress = progress * 100.0
                    self?.updateGlobalProgress()
                }
            }
        }
    }
    
    private func resumeSendingChunks(_ transferState: FileTransferState) {
        guard let fileData = transferState.fileData else { return }
        
        let chunks = createFileChunks(fileData, fileID: transferState.transferID)
        let missingChunks = Set(0..<UInt32(chunks.count)).subtracting(transferState.ackedChunks)
        
        transferQueue.async { [weak self] in
            for chunkIndex in missingChunks.sorted() {
                guard chunkIndex < chunks.count else { continue }
                
                // Check if transfer is still active
                guard transferState.status != .cancelled,
                      transferState.status != .paused else {
                    break
                }
                
                let chunk = chunks[Int(chunkIndex)]
                self?.sendFileChunk(chunk, to: transferState.peerID)
                
                // Rate limiting
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    private func completeFileReceive(_ transferState: FileTransferState) {
        // Reassemble file from chunks
        var completeFileData = Data()
        for i in 0..<transferState.manifest.totalChunks {
            if let chunkData = transferState.receivedChunks[i] {
                completeFileData.append(chunkData)
            } else {
                print("❌ Missing chunk \(i) in completed transfer")
                transferState.status = .failed(reason: "Missing chunks", canRetry: true)
                return
            }
        }
        
        // Verify file integrity
        let receivedHash = SHA256.hash(data: completeFileData).compactMap { String(format: "%02x", $0) }.joined()
        guard receivedHash == transferState.manifest.sha256Hash else {
            print("❌ File integrity check failed")
            transferState.status = .failed(reason: "File integrity check failed", canRetry: true)
            return
        }
        
        // Save file to Downloads directory
        do {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileURL = downloadsURL.appendingPathComponent(transferState.manifest.fileName)
            try completeFileData.write(to: fileURL)
            
            transferState.status = .completed(fileURL: fileURL)
            transferState.progress = 100.0
            
            // Move to completed transfers
            let completedTransfer = CompletedTransfer(
                transferID: transferState.transferID,
                fileName: transferState.manifest.fileName,
                fileSize: transferState.manifest.fileSize,
                peerName: transferState.peerNickname,
                direction: .receive,
                completionTime: Date(),
                fileURL: fileURL
            )
            completedTransfers.insert(completedTransfer, at: 0)
            
            // Remove from active transfers
            activeTransfers.removeAll { $0.transferID == transferState.transferID }
            updateGlobalProgress()
            
            print("✅ File transfer completed: \(transferState.manifest.fileName)")
            
        } catch {
            print("❌ Error saving received file: \(error)")
            transferState.status = .failed(reason: "Could not save file", canRetry: false)
        }
        
        updateTransferInHistory(transferState.transferID, status: transferState.status)
    }
    
    private func completeFileTransfer(_ transferState: FileTransferState) {
        transferState.status = .completed(fileURL: URL(string: "")!) // Placeholder for send transfers
        transferState.progress = 100.0
        
        let completedTransfer = CompletedTransfer(
            transferID: transferState.transferID,
            fileName: transferState.manifest.fileName,
            fileSize: transferState.manifest.fileSize,
            peerName: transferState.peerNickname,
            direction: transferState.direction,
            completionTime: Date(),
            fileURL: nil
        )
        completedTransfers.insert(completedTransfer, at: 0)
        
        // Calculate transfer statistics
        if let startTime = transferStartTimes[transferState.transferID] {
            let duration = Date().timeIntervalSince(startTime)
            let averageSpeed = UInt64(Double(transferState.manifest.fileSize) / duration)
            print("✅ Transfer completed in \(String(format: "%.1f", duration))s at \(ByteCountFormatter.string(fromByteCount: Int64(averageSpeed), countStyle: .file))/s")
            transferStartTimes.removeValue(forKey: transferState.transferID)
        }
        
        // Remove from active transfers
        activeTransfers.removeAll { $0.transferID == transferState.transferID }
        updateGlobalProgress()
        processTransferQueue()
        
        updateTransferInHistory(transferState.transferID, status: transferState.status)
    }
    
    // MARK: - Network Communication
    
    private func sendFileManifest(_ manifest: FILE_MANIFEST, to peerID: String) {
        guard let meshService = meshService,
              let payload = manifest.toBinaryPayload() else {
            return
        }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_MANIFEST.rawValue,
            ttl: FileTransferConstants.MAX_HOPS,
            senderID: meshService.myPeerID,
            payload: payload
        )
        
        // Send via mesh service
        meshService.broadcastFileTransferPacket(packet)
        print("📤 Sending manifest: \(manifest.fileName) to \(peerID)")
    }
    
    private func sendFileChunk(_ chunk: FILE_CHUNK, to peerID: String) {
        guard let meshService = meshService,
              let payload = chunk.toBinaryPayload() else {
            return
        }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_CHUNK.rawValue,
            ttl: FileTransferConstants.MAX_HOPS,
            senderID: meshService.myPeerID,
            payload: payload
        )
        
        // Send via mesh service
        meshService.broadcastFileTransferPacket(packet)
        bytesTransferredSinceLastUpdate += UInt64(chunk.payload.count)
    }
    
    private func sendInitialAck(for manifest: FILE_MANIFEST, to peerID: String) {
        let ack = FILE_ACK(
            fileID: manifest.fileID,
            receiverID: meshService?.myPeerID ?? "unknown",
            acknowledgedChunks: [],
            totalChunks: manifest.totalChunks
        )
        
        sendFileAck(ack, to: peerID)
    }
    
    private func sendChunkAck(for chunk: FILE_CHUNK, to peerID: String) {
        guard let transferState = activeTransfers.first(where: { $0.transferID == chunk.fileID }) else {
            return
        }
        
        let ack = FILE_ACK(
            fileID: chunk.fileID,
            receiverID: meshService?.myPeerID ?? "unknown",
            acknowledgedChunks: transferState.completedChunks,
            totalChunks: transferState.manifest.totalChunks
        )
        
        sendFileAck(ack, to: peerID)
    }
    
    private func sendFileAck(_ ack: FILE_ACK, to peerID: String) {
        guard let meshService = meshService,
              let payload = ack.toBinaryPayload() else {
            return
        }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_ACK.rawValue,
            ttl: FileTransferConstants.MAX_HOPS,
            senderID: meshService.myPeerID,
            payload: payload
        )
        
        // Send via mesh service
        meshService.broadcastFileTransferPacket(packet)
    }
    
    // MARK: - Helper Methods
    
    private func createFileChunks(_ fileData: Data, fileID: String) -> [FILE_CHUNK] {
        let chunkSize = FileTransferConstants.CHUNK_SIZE
        let totalChunks = (fileData.count + chunkSize - 1) / chunkSize
        var chunks: [FILE_CHUNK] = []
        
        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, fileData.count)
            let chunkData = fileData.subdata(in: start..<end)
            let isLastChunk = (i == totalChunks - 1)
            
            let chunk = FILE_CHUNK(
                fileID: fileID,
                chunkIndex: UInt32(i),
                payload: chunkData,
                isLastChunk: isLastChunk
            )
            
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    private func verifyChunkIntegrity(_ chunk: FILE_CHUNK) -> Bool {
        let calculatedHash = SHA256.hash(data: chunk.payload).compactMap { String(format: "%02x", $0) }.joined()
        return calculatedHash == chunk.chunkHash
    }
    
    private func updateGlobalProgress() {
        let totalTransfers = activeTransfers.count
        guard totalTransfers > 0 else {
            globalProgress = 0.0
            isTransferring = false
            return
        }
        
        let totalProgress = activeTransfers.reduce(0.0) { $0 + $1.progress }
        globalProgress = totalProgress / Double(totalTransfers)
        isTransferring = activeTransfers.contains { $0.isActive }
    }
    
    private func updateTransferInHistory(_ transferID: String, status: FileTransferStatus) {
        if let index = transferHistory.firstIndex(where: { $0.transferID == transferID }) {
            transferHistory[index].status = status
            transferHistory[index].lastUpdated = Date()
        }
    }
    
    private func setupPerformanceMonitoring() {
        // Update transfer speeds every second
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTransferSpeeds()
        }
    }
    
    private func updateTransferSpeeds() {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastProgressUpdate)
        
        if timeDelta > 0 {
            currentTransferSpeed = UInt64(Double(bytesTransferredSinceLastUpdate) / timeDelta)
            bytesTransferredSinceLastUpdate = 0
            lastProgressUpdate = now
        }
    }
    
    private func setupNotificationHandlers() {
        // Handle app lifecycle for proper cleanup
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseAllActiveTransfers()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.resumeAllPausedTransfers()
            }
            .store(in: &cancellables)
    }
    
    private func setupMeshServiceIntegration() {
        // This would integrate with the actual BluetoothMeshService
        // to handle incoming file transfer messages
    }
    
    private func initializeStorageDirectories() {
        do {
            try FileStorageManager.initializeStorage()
        } catch {
            print("Error initializing storage: \(error)")
        }
    }
    
    private func cleanupTransferFiles(_ transferID: String) {
        // Remove temporary files for cancelled transfers
        let tempURL = FileStorageManager.createTemporaryFile(for: transferID)
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    private func pauseAllActiveTransfers() {
        for transfer in activeTransfers {
            if transfer.isActive {
                pauseTransfer(transfer.transferID)
            }
        }
    }
    
    private func resumeAllPausedTransfers() {
        for transfer in activeTransfers {
            if case .paused = transfer.status {
                resumeTransfer(transfer.transferID)
            }
        }
    }
    
    private func requestChunkRetry(_ fileID: String, chunkIndex: UInt32, to peerID: String) {
        // Send targeted retry request
        let ack = FILE_ACK(
            fileID: fileID,
            receiverID: meshService?.myPeerID ?? "unknown",
            acknowledgedChunks: [],
            totalChunks: 0
        )
        // Note: Would set specific retry parameters
        sendFileAck(ack, to: peerID)
    }
    
    private func retransmitChunks(_ chunkIndices: [UInt32], for fileID: String, to peerID: String) {
        guard let transferState = activeTransfers.first(where: { $0.transferID == fileID }),
              let fileData = transferState.fileData else {
            return
        }
        
        let allChunks = createFileChunks(fileData, fileID: fileID)
        
        transferQueue.async { [weak self] in
            for chunkIndex in chunkIndices {
                guard Int(chunkIndex) < allChunks.count else { continue }
                
                let chunk = allChunks[Int(chunkIndex)]
                self?.sendFileChunk(chunk, to: peerID)
                
                // Rate limiting for retransmissions
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }
}

// MARK: - Supporting Data Structures

struct QueuedTransfer: Identifiable {
    let id = UUID()
    let transferID: String
    let fileURL: URL
    let manifest: FILE_MANIFEST
    let peerID: String
    let peerNickname: String
    let priority: TransferPriority
    let queueTime: Date
}

struct CompletedTransfer: Identifiable {
    let id = UUID()
    let transferID: String
    let fileName: String
    let fileSize: UInt64
    let peerName: String
    let direction: TransferDirection
    let completionTime: Date
    let fileURL: URL?
    
    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

/// Observable state for individual file transfers
class FileTransferState: ObservableObject, Identifiable {
    let id = UUID()
    let transferID: String
    let manifest: FILE_MANIFEST
    let direction: TransferDirection
    let peerID: String
    let peerNickname: String
    
    @Published var status: FileTransferStatus = .preparing
    @Published var progress: Double = 0.0
    @Published var transferSpeed: String = ""
    @Published var estimatedTimeRemaining: String = ""
    
    // Transfer data
    var fileData: Data? // For send transfers
    var receivedChunks: [UInt32: Data] = [:] // For receive transfers
    var completedChunks: Set<UInt32> = []
    var ackedChunks: Set<UInt32> = [] // For send transfers
    var failedChunks: Set<UInt32> = []
    var totalChunks: [FILE_CHUNK] = [] // For send transfers
    
    // Timing
    let startTime: Date
    var lastActivityTime: Date
    
    init(transferID: String, manifest: FILE_MANIFEST, direction: TransferDirection, peerID: String, peerNickname: String) {
        self.transferID = transferID
        self.manifest = manifest
        self.direction = direction
        self.peerID = peerID
        self.peerNickname = peerNickname
        self.startTime = Date()
        self.lastActivityTime = Date()
    }
    
    var isActive: Bool {
        switch status {
        case .transferring, .preparing:
            return true
        default:
            return false
        }
    }
    
    var displayProgress: String {
        return "\(Int(progress))%"
    }
    
    var displayStatus: String {
        return status.displayText
    }
}