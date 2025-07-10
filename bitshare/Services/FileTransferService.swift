//
// FileTransferService.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit
import Combine

// MARK: - PRD Section 3.2: File Transfer Service Implementation

class FileTransferService: ObservableObject {
    static let shared = FileTransferService()
    
    // PRD Section 5.1: Active transfer tracking
    @Published var activeTransfers: [String: FileTransfer] = [:]
    @Published var transferProgress: [String: Double] = [:]
    
    private let encryptionService = EncryptionService()
    private var meshService: BluetoothMeshService?
    private let transferQueue = DispatchQueue(label: "bitshare.fileTransfer", qos: .userInitiated)
    
    // PRD Section 3.2: Chunking configuration
    private let chunkSize = FileTransferConstants.CHUNK_SIZE  // 480 bytes
    private let maxRetries = 3
    private let chunkTimeout: TimeInterval = 30.0
    
    private init() {
        setupMeshServiceIntegration()
    }
    
    // MARK: - PRD Section 5.1: Primary File Transfer Methods
    
    func setMeshService(_ meshService: BluetoothMeshService) {
        self.meshService = meshService
        setupMeshServiceIntegration()
    }
    
    /// PRD Section 5.1: Send file to peer with drag-and-drop support
    func sendFile(_ fileURL: URL, to peerID: String, peerNickname: String) -> String? {
        guard let meshService = meshService else {
            print("FileTransferService: MeshService not available")
            return nil
        }
        
        do {
            // Calculate file hash for integrity (PRD requirement)
            let fileData = try Data(contentsOf: fileURL)
            let fileHash = SHA256.hash(data: fileData)
            let hashString = fileHash.compactMap { String(format: "%02x", $0) }.joined()
            
            // Create manifest with PRD specifications
            let transferID = UUID().uuidString
            let manifest = FileManifest(
                fileID: transferID,
                fileName: fileURL.lastPathComponent,
                fileSize: UInt64(fileData.count),
                sha256Hash: hashString,
                senderID: meshService.myPeerID,
                mimeType: getMimeType(for: fileURL)
            )
            
            // Create transfer state
            let transfer = FileTransfer(
                transferID: transferID,
                manifest: manifest,
                fileData: fileData,
                peerID: peerID,
                peerNickname: peerNickname,
                direction: .send
            )
            
            activeTransfers[transferID] = transfer
            
            // Send manifest
            sendFileManifest(manifest, to: peerID)
            
            return transferID
            
        } catch {
            print("FileTransferService: Error reading file: \(error)")
            return nil
        }
    }
    
    /// PRD Section 3.2: Resume transfer capabilities
    func resumeTransfer(_ transferID: String) {
        guard let transfer = activeTransfers[transferID] else { return }
        
        switch transfer.status {
        case .paused:
            transfer.status = .transferring(chunksReceived: UInt32(transfer.completedChunks.count), totalChunks: transfer.manifest.totalChunks)
            if transfer.direction == .send {
                resumeSendingChunks(transfer)
            }
        default:
            break
        }
    }
    
    /// PRD Section 3.2: Pause transfer capabilities  
    func pauseTransfer(_ transferID: String) {
        guard let transfer = activeTransfers[transferID] else { return }
        
        if case .transferring = transfer.status {
            transfer.status = .paused(at: UInt32(transfer.completedChunks.count))
        }
    }
    
    /// PRD Section 5.1: Cancel transfer
    func cancelTransfer(_ transferID: String) {
        guard let transfer = activeTransfers[transferID] else { return }
        
        transfer.status = .cancelled
        activeTransfers.removeValue(forKey: transferID)
        transferProgress.removeValue(forKey: transferID)
    }
    
    // MARK: - PRD Section 3.2: Protocol Implementation
    
    private func sendFileManifest(_ manifest: FileManifest, to peerID: String) {
        guard let meshService = meshService,
              let manifestData = manifest.encode() else { return }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_MANIFEST.rawValue,
            ttl: FileTransferConstants.MAX_HOPS,
            senderID: meshService.myPeerID,
            payload: manifestData
        )
        
        // Send via mesh service
        meshService.broadcastFileTransferPacket(packet)
        print("Sending FILE_MANIFEST for \(manifest.fileName) to \(peerID)")
    }
    
    private func sendFileChunk(_ chunk: FileChunk, to peerID: String) {
        guard let meshService = meshService,
              let chunkData = chunk.encode() else { return }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_CHUNK.rawValue,
            ttl: FileTransferConstants.MAX_HOPS,
            senderID: meshService.myPeerID,
            payload: chunkData
        )
        
        // Send via mesh service
        meshService.broadcastFileTransferPacket(packet)
        print("Sending chunk \(chunk.chunkIndex) for file \(chunk.fileID)")
    }
    
    private func sendFileAck(_ ack: FileChunkAck, to peerID: String) {
        guard let meshService = meshService,
              let ackData = ack.encode() else { return }
        
        let packet = BitchatPacket(
            type: MessageType.FILE_ACK.rawValue,
            ttl: FileTransferConstants.MAX_HOPS,
            senderID: meshService.myPeerID,
            payload: ackData
        )
        
        // Send via mesh service
        meshService.broadcastFileTransferPacket(packet)
        print("Sending ACK for chunk \(ack.chunkIndex) of file \(ack.fileID)")
    }
    
    // MARK: - PRD Section 3.2: Chunking Implementation
    
    private func chunkFile(_ fileData: Data) -> [FileChunk] {
        let totalChunks = (fileData.count + chunkSize - 1) / chunkSize
        var chunks: [FileChunk] = []
        
        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, fileData.count)
            let chunkData = fileData.subdata(in: start..<end)
            
            let chunk = FileChunk(
                fileID: "", // Will be set by caller
                chunkIndex: UInt32(i),
                payload: chunkData
            )
            
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    private func resumeSendingChunks(_ transfer: FileTransfer) {
        guard let fileData = transfer.fileData else { return }
        
        let chunks = chunkFile(fileData)
        
        // Send remaining chunks
        transferQueue.async { [weak self] in
            for (index, chunk) in chunks.enumerated() {
                let chunkIndex = UInt32(index)
                
                // Skip already completed chunks
                if transfer.completedChunks.contains(chunkIndex) {
                    continue
                }
                
                // Check if transfer is still active
                guard transfer.status.percentageComplete < 100.0 else { break }
                
                var chunkWithID = chunk
                chunkWithID = FileChunk(
                    fileID: transfer.transferID,
                    chunkIndex: chunkIndex,
                    payload: chunk.payload
                )
                
                self?.sendFileChunk(chunkWithID, to: transfer.peerID)
                
                // Add delay between chunks to avoid overwhelming the mesh
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    // MARK: - Message Handlers
    
    func handleFileManifest(_ manifest: FileManifest, from peerID: String, peerNickname: String) {
        // Create incoming transfer
        let transfer = FileTransfer(
            transferID: manifest.fileID,
            manifest: manifest,
            fileData: nil,
            peerID: peerID,
            peerNickname: peerNickname,
            direction: .receive
        )
        
        activeTransfers[manifest.fileID] = transfer
        transfer.status = .transferring(chunksReceived: 0, totalChunks: manifest.totalChunks)
        
        print("Receiving file: \(manifest.fileName) (\(manifest.fileSize) bytes) from \(peerNickname)")
    }
    
    func handleFileChunk(_ chunk: FileChunk, from peerID: String) {
        guard let transfer = activeTransfers[chunk.fileID] else {
            print("Received chunk for unknown transfer: \(chunk.fileID)")
            return
        }
        
        // Verify chunk hash
        let expectedHash = chunk.chunkHash
        let actualHash = SHA256.hash(data: chunk.payload).compactMap { String(format: "%02x", $0) }.joined()
        
        guard expectedHash == actualHash else {
            print("Chunk hash mismatch for chunk \(chunk.chunkIndex)")
            return
        }
        
        // Store chunk
        transfer.receivedChunks[chunk.chunkIndex] = chunk.payload
        transfer.completedChunks.insert(chunk.chunkIndex)
        
        // Send ACK
        let ack = FileChunkAck(
            fileID: chunk.fileID,
            chunkIndex: chunk.chunkIndex,
            receiverID: meshService?.myPeerID ?? "unknown"
        )
        sendFileAck(ack, to: peerID)
        
        // Update progress
        let progress = Double(transfer.completedChunks.count) / Double(transfer.manifest.totalChunks) * 100.0
        transferProgress[chunk.fileID] = progress
        
        transfer.status = .transferring(
            chunksReceived: UInt32(transfer.completedChunks.count),
            totalChunks: transfer.manifest.totalChunks
        )
        
        // Check if complete
        if transfer.completedChunks.count == transfer.manifest.totalChunks {
            completeFileTransfer(transfer)
        }
    }
    
    func handleFileAck(_ ack: FileChunkAck, from peerID: String) {
        guard let transfer = activeTransfers[ack.fileID] else { return }
        
        transfer.completedChunks.insert(ack.chunkIndex)
        
        // Update progress
        let progress = Double(transfer.completedChunks.count) / Double(transfer.manifest.totalChunks) * 100.0
        transferProgress[ack.fileID] = progress
        
        transfer.status = .transferring(
            chunksReceived: UInt32(transfer.completedChunks.count),
            totalChunks: transfer.manifest.totalChunks
        )
        
        print("Received ACK for chunk \(ack.chunkIndex) of file \(ack.fileID)")
    }
    
    // MARK: - Helper Methods
    
    private func completeFileTransfer(_ transfer: FileTransfer) {
        guard transfer.direction == .receive else { return }
        
        // Reassemble file
        var fileData = Data()
        for i in 0..<transfer.manifest.totalChunks {
            if let chunkData = transfer.receivedChunks[i] {
                fileData.append(chunkData)
            }
        }
        
        // Verify file integrity
        let fileHash = SHA256.hash(data: fileData).compactMap { String(format: "%02x", $0) }.joined()
        
        guard fileHash == transfer.manifest.sha256Hash else {
            transfer.status = .failed(reason: "File integrity check failed")
            return
        }
        
        // Save file
        do {
            let documentsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent(transfer.manifest.fileName)
            try fileData.write(to: fileURL)
            
            transfer.status = .completed(fileURL: fileURL)
            transferProgress[transfer.transferID] = 100.0
            
            print("File transfer completed: \(transfer.manifest.fileName)")
            
        } catch {
            transfer.status = .failed(reason: "Failed to save file: \(error.localizedDescription)")
        }
    }
    
    private func setupMeshServiceIntegration() {
        // File transfer integration is handled through ChatViewModel's BitchatDelegate
        // which forwards file transfer messages to this service via FileTransferManager
        print("FileTransferService: Mesh service integration ready")
    }
    
    private func getMimeType(for url: URL) -> String {
        // Simple MIME type detection based on file extension
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt": return "text/plain"
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "mp4": return "video/mp4"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - File Transfer State Management

class FileTransfer: ObservableObject {
    let transferID: String
    let manifest: FileManifest
    let fileData: Data?  // For send transfers
    let peerID: String
    let peerNickname: String
    let direction: TransferDirection
    
    @Published var status: FileTransferStatus
    var receivedChunks: [UInt32: Data] = [:]  // For receive transfers
    var completedChunks: Set<UInt32> = []
    let startTime: Date
    
    init(transferID: String, manifest: FileManifest, fileData: Data?, peerID: String, peerNickname: String, direction: TransferDirection) {
        self.transferID = transferID
        self.manifest = manifest
        self.fileData = fileData
        self.peerID = peerID
        self.peerNickname = peerNickname
        self.direction = direction
        self.status = .preparing
        self.startTime = Date()
    }
    
    var progress: Double {
        guard manifest.totalChunks > 0 else { return 0.0 }
        return Double(completedChunks.count) / Double(manifest.totalChunks) * 100.0
    }
}