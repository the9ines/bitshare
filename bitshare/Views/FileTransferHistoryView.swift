//
// FileTransferHistoryView.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI

/// PRD Section 5.1: Transfer History View (MVP Requirement)
/// Shows complete file transfer history with bitchat visual consistency
struct FileTransferHistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: TransferFilter = .all
    @State private var showingClearAlert = false
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    enum TransferFilter: String, CaseIterable {
        case all = "All"
        case sent = "Sent"
        case received = "Received"
        case failed = "Failed"
        case completed = "Completed"
        
        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .sent: return "arrow.up.circle"
            case .received: return "arrow.down.circle"
            case .failed: return "exclamationmark.triangle"
            case .completed: return "checkmark.circle"
            }
        }
    }
    
    /// Filtered transfer history based on search and filter
    private var filteredHistory: [TransferRecord] {
        var filtered = viewModel.transferHistory
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .sent:
            filtered = filtered.filter { $0.direction == .send }
        case .received:
            filtered = filtered.filter { $0.direction == .receive }
        case .failed:
            filtered = filtered.filter {
                if case .failed = $0.status { return true }
                return false
            }
        case .completed:
            filtered = filtered.filter {
                if case .completed = $0.status { return true }
                return false
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { record in
                record.fileName.localizedCaseInsensitiveContains(searchText) ||
                record.senderReceiver.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with bitchat styling (44px height)
                headerView
                    .frame(height: 44)
                
                Divider()
                
                // Search and filter controls
                searchAndFilterView
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                Divider()
                
                // Transfer history list
                if filteredHistory.isEmpty {
                    emptyStateView
                } else {
                    transferHistoryList
                }
            }
            .background(backgroundColor)
            .navigationBarHidden(true)
        }
        .alert("Clear History", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                viewModel.clearTransferHistory()
            }
        } message: {
            Text("This will permanently delete all transfer history. This action cannot be undone.")
        }
    }
    
    /// Header view with bitchat consistency
    private var headerView: some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                    Text("back")
                        .font(.system(size: 14, design: .monospaced))
                }
                .foregroundColor(textColor)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Title
            Text("Transfer History")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(textColor)
            
            Spacer()
            
            // Clear button
            Button("Clear") {
                showingClearAlert = true
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(Color.red.opacity(0.8))
            .disabled(viewModel.transferHistory.isEmpty)
        }
        .padding(.horizontal, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    /// Search and filter controls
    private var searchAndFilterView: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
                
                TextField("Search transfers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(textColor)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(secondaryTextColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(6)
            
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TransferFilter.allCases, id: \.self) { filter in
                        filterButton(for: filter)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    /// Filter button with bitchat styling
    private func filterButton(for filter: TransferFilter) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedFilter = filter
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.system(size: 12))
                
                Text(filter.rawValue)
                    .font(.system(size: 12, design: .monospaced))
                
                // Count badge
                let count = getFilterCount(for: filter)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(selectedFilter == filter ? backgroundColor : textColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedFilter == filter ? textColor.opacity(0.3) : secondaryTextColor.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(selectedFilter == filter ? backgroundColor : textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedFilter == filter ? textColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedFilter == filter ? Color.clear : secondaryTextColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    /// Get count for filter type
    private func getFilterCount(for filter: TransferFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.transferHistory.count
        case .sent:
            return viewModel.transferHistory.filter { $0.direction == .send }.count
        case .received:
            return viewModel.transferHistory.filter { $0.direction == .receive }.count
        case .failed:
            return viewModel.transferHistory.filter {
                if case .failed = $0.status { return true }
                return false
            }.count
        case .completed:
            return viewModel.transferHistory.filter {
                if case .completed = $0.status { return true }
                return false
            }.count
        }
    }
    
    /// Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor.opacity(0.5))
            
            Text(searchText.isEmpty ? "No transfers yet" : "No transfers match your search")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(secondaryTextColor)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search or filter")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(secondaryTextColor.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Transfer history list
    private var transferHistoryList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredHistory, id: \.id) { record in
                    TransferHistoryRowView(record: record, viewModel: viewModel)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// Individual transfer history row
struct TransferHistoryRowView: View {
    let record: TransferRecord
    let viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    
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
            // Main row
            HStack(spacing: 12) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 16))
                    .foregroundColor(statusColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Filename
                    Text(record.fileName)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Transfer details
                    HStack(spacing: 8) {
                        // File size
                        Text(ByteCountFormatter.string(fromByteCount: Int64(record.fileSize), countStyle: .file))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor.opacity(0.5))
                        
                        // Direction and peer
                        HStack(spacing: 4) {
                            Text(record.direction == .send ? "→" : "←")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(record.direction == .send ? textColor : Color.blue)
                            
                            Text(record.senderReceiver)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor.opacity(0.5))
                        
                        // Timestamp
                        Text(record.timestamp, style: .relative)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    // Status text
                    Text(record.status.displayText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(statusColor)
                        .lineLimit(1)
                    
                    // Retry indicator
                    if record.isRetry {
                        Text("retry")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
            }
            
            // Retry button for failed transfers
            if case .failed(_, let canRetry) = record.status, canRetry {
                HStack {
                    Spacer()
                    
                    Button("Retry Transfer") {
                        viewModel.retryFailedTransfer(record.transferID)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(textColor)
                    .cornerRadius(4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(secondaryTextColor.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(6)
    }
    
    /// Status icon based on transfer status
    private var statusIcon: String {
        switch record.status {
        case .preparing:
            return "clock"
        case .transferring:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .paused:
            return "pause.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    /// Status color based on transfer status
    private var statusColor: Color {
        switch record.status {
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
}

// MARK: - Preview Provider

#if DEBUG
struct FileTransferHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        FileTransferHistoryView(viewModel: sampleViewModel)
            .preferredColorScheme(.dark)
    }
    
    static var sampleViewModel: ChatViewModel {
        let vm = ChatViewModel()
        
        // Add sample transfer records
        vm.transferHistory = [
            TransferRecord(
                transferID: "1",
                fileName: "vacation-photos.zip",
                fileSize: 1024 * 1024 * 50,
                senderReceiver: "Alice",
                direction: .send,
                status: .completed(fileURL: URL(string: "file://test")!),
                timestamp: Date().addingTimeInterval(-3600),
                lastUpdated: Date().addingTimeInterval(-3500)
            ),
            TransferRecord(
                transferID: "2",
                fileName: "document.pdf",
                fileSize: 1024 * 500,
                senderReceiver: "Bob",
                direction: .receive,
                status: .failed(reason: "Connection lost", canRetry: true),
                timestamp: Date().addingTimeInterval(-7200),
                lastUpdated: Date().addingTimeInterval(-7100)
            ),
            TransferRecord(
                transferID: "3",
                fileName: "presentation.pptx",
                fileSize: 1024 * 1024 * 10,
                senderReceiver: "Charlie",
                direction: .send,
                status: .transferring(chunksReceived: 45, totalChunks: 100),
                timestamp: Date().addingTimeInterval(-300),
                lastUpdated: Date().addingTimeInterval(-10)
            )
        ]
        
        return vm
    }
}
#endif