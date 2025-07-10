//
// FileTransferProgressView.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI
import UniformTypeIdentifiers

/// Real-time file transfer progress view with bitchat visual consistency
struct FileTransferProgressView: View {
    @ObservedObject var transfer: FileTransferState
    @Environment(\.colorScheme) var colorScheme
    @State private var animationOffset: CGFloat = 0
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File info header with bitchat styling
            HStack(spacing: 12) {
                // File type icon
                Image(systemName: fileIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Filename with monospace font (bitchat consistency)
                    Text(transfer.manifest.fileName)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // File size and peer info
                    HStack(spacing: 8) {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(transfer.manifest.fileSize), countStyle: .file))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                        
                        Text("•")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(secondaryTextColor.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Text(transfer.direction == .send ? "→" : "←")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(transfer.direction == .send ? textColor : Color.blue)
                            
                            Text(transfer.peerNickname)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                
                Spacer()
                
                // Progress percentage with bitchat styling
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(transfer.progress))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(textColor)
                    
                    Text(transfer.displayStatus)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }
            }
            
            // Progress bar with bitchat-style animation
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(secondaryTextColor.opacity(0.2))
                            .frame(height: 6)
                        
                        // Progress fill with animation
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * (transfer.progress / 100.0), height: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: transfer.progress)
                        
                        // Animated shimmer effect for active transfers
                        if transfer.isActive {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            progressColor.opacity(0.3),
                                            progressColor.opacity(0.8),
                                            progressColor.opacity(0.3)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * 0.3, height: 6)
                                .offset(x: animationOffset)
                                .animation(
                                    Animation.linear(duration: 1.5)
                                        .repeatForever(autoreverses: false),
                                    value: animationOffset
                                )
                                .onAppear {
                                    animationOffset = geometry.size.width * 1.3
                                }
                                .onChange(of: geometry.size.width) { width in
                                    animationOffset = width * 1.3
                                }
                        }
                    }
                }
                .frame(height: 6)
                
                // Transfer details row
                HStack {
                    // Transfer speed (when active)
                    if transfer.isActive && !transfer.transferSpeed.isEmpty {
                        Text("\(transfer.transferSpeed)/s")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Estimated time remaining
                    if transfer.isActive && !transfer.estimatedTimeRemaining.isEmpty {
                        Text("~\(transfer.estimatedTimeRemaining)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    // Chunk progress for detailed view
                    if transfer.isActive {
                        Text("\(transfer.completedChunks.count)/\(transfer.manifest.totalChunks) chunks")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(secondaryTextColor.opacity(0.7))
                    }
                }
            }
            
            // Action buttons (for failed/paused transfers)
            if case .failed = transfer.status {
                HStack(spacing: 8) {
                    // Retry button
                    Button("Retry") {
                        // TODO: Implement retry action
                        print("Retry transfer: \(transfer.transferID)")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(textColor)
                    .cornerRadius(4)
                    
                    // Cancel button
                    Button("Cancel") {
                        // TODO: Implement cancel action
                        print("Cancel transfer: \(transfer.transferID)")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                    
                    Spacer()
                }
            } else if case .paused = transfer.status {
                HStack(spacing: 8) {
                    // Resume button
                    Button("Resume") {
                        // TODO: Implement resume action
                        print("Resume transfer: \(transfer.transferID)")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(textColor)
                    .cornerRadius(4)
                    
                    // Cancel button
                    Button("Cancel") {
                        // TODO: Implement cancel action
                        print("Cancel transfer: \(transfer.transferID)")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12) // bitchat standard padding
        .padding(.vertical, 12)
        .background(backgroundColor.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(secondaryTextColor.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
    
    /// Progress bar color based on transfer status
    private var progressColor: Color {
        switch transfer.status {
        case .preparing, .transferring:
            return textColor
        case .completed:
            return textColor
        case .failed:
            return Color.red
        case .paused:
            return Color.orange
        case .cancelled:
            return Color.gray
        }
    }
    
    /// File type icon based on file extension
    private var fileIcon: String {
        let ext = (transfer.manifest.fileName as NSString).pathExtension.lowercased()
        
        // First check MIME type if available
        if let mimeType = transfer.manifest.mimeType {
            let primaryType = mimeType.components(separatedBy: "/").first?.lowercased() ?? ""
            switch primaryType {
            case "image":
                return "photo"
            case "video":
                return "video"
            case "audio":
                return "music.note"
            case "text":
                return "doc.text"
            case "application":
                if mimeType.contains("pdf") {
                    return "doc.richtext"
                } else if mimeType.contains("zip") || mimeType.contains("archive") {
                    return "archivebox"
                }
            default:
                break
            }
        }
        
        // Fallback to file extension
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm":
            return "video"
        case "mp3", "wav", "flac", "aac", "ogg", "m4a":
            return "music.note"
        case "txt", "md", "rtf":
            return "doc.text"
        case "pdf":
            return "doc.richtext"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "doc", "docx":
            return "doc"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "json", "xml", "csv":
            return "doc.plaintext"
        case "swift", "py", "js", "html", "css", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct FileTransferProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Active transfer
            FileTransferProgressView(transfer: sampleActiveTransfer)
            
            // Completed transfer
            FileTransferProgressView(transfer: sampleCompletedTransfer)
            
            // Failed transfer
            FileTransferProgressView(transfer: sampleFailedTransfer)
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    static var sampleActiveTransfer: FileTransferState {
        let manifest = FILE_MANIFEST(
            fileID: "sample-1",
            fileName: "vacation-photos.zip",
            fileSize: 1024 * 1024 * 50, // 50MB
            sha256Hash: "abc123",
            senderID: "peer1"
        )
        
        let transfer = FileTransferState(
            transferID: "sample-1",
            manifest: manifest,
            direction: .send,
            peerID: "peer1",
            peerNickname: "Alice"
        )
        
        transfer.progress = 67.0
        transfer.status = .transferring(chunksReceived: 67, totalChunks: 100)
        transfer.transferSpeed = "2.3 MB"
        transfer.estimatedTimeRemaining = "15s"
        
        return transfer
    }
    
    static var sampleCompletedTransfer: FileTransferState {
        let manifest = FILE_MANIFEST(
            fileID: "sample-2",
            fileName: "document.pdf",
            fileSize: 1024 * 500, // 500KB
            sha256Hash: "def456",
            senderID: "peer2"
        )
        
        let transfer = FileTransferState(
            transferID: "sample-2",
            manifest: manifest,
            direction: .receive,
            peerID: "peer2",
            peerNickname: "Bob"
        )
        
        transfer.progress = 100.0
        transfer.status = .completed(fileURL: URL(string: "file://test")!)
        
        return transfer
    }
    
    static var sampleFailedTransfer: FileTransferState {
        let manifest = FILE_MANIFEST(
            fileID: "sample-3",
            fileName: "large-video.mp4",
            fileSize: 1024 * 1024 * 200, // 200MB
            sha256Hash: "ghi789",
            senderID: "peer3"
        )
        
        let transfer = FileTransferState(
            transferID: "sample-3",
            manifest: manifest,
            direction: .send,
            peerID: "peer3",
            peerNickname: "Charlie"
        )
        
        transfer.progress = 45.0
        transfer.status = .failed(reason: "Connection lost", canRetry: true)
        
        return transfer
    }
}
#endif