//
// TransportStatusView.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI

// MARK: - Transport Status Indicator

/// Visual indicator showing active transport and performance
struct TransportStatusView: View {
    @ObservedObject var transportManager: TransportManager
    @ObservedObject var fileTransferManager: FileTransferManager
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Primary transport indicator
            transportIndicator
            
            // Speed multiplier display
            if fileTransferManager.transportSpeedMultiplier > 1.0 {
                speedBoostIndicator
            }
            
            // Detailed transport view
            if showDetails {
                transportDetailsView
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(transportColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showDetails.toggle()
            }
        }
    }
    
    // MARK: - Primary Transport Indicator
    
    private var transportIndicator: some View {
        HStack(spacing: 8) {
            // Transport icon with animation
            Image(systemName: transportManager.primaryTransport.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(transportColor)
                .scaleEffect(transportManager.isDiscovering ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: transportManager.isDiscovering)
            
            // Transport name
            Text(transportManager.primaryTransport.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Connection status
            connectionStatusView
            
            // Expand/collapse chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(showDetails ? 180 : 0))
                .animation(.spring(response: 0.3), value: showDetails)
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(transportManager.isDiscovering ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: transportManager.isDiscovering)
            
            Text("\(transportManager.allPeers.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Speed Boost Indicator
    
    private var speedBoostIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.orange)
            
            Text("\(Int(fileTransferManager.transportSpeedMultiplier))x faster")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
            
            Spacer()
        }
    }
    
    // MARK: - Detailed Transport View
    
    private var transportDetailsView: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Available transports
            availableTransportsView
            
            // Transport statistics
            if !transportManager.statistics.isEmpty {
                statisticsView
            }
            
            // Transport switching controls
            transportSwitchingView
        }
    }
    
    // MARK: - Available Transports
    
    private var availableTransportsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Transports")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(transportManager.availableTransports, id: \.self) { transportType in
                    transportCard(for: transportType)
                }
            }
        }
    }
    
    private func transportCard(for transportType: TransportType) -> some View {
        VStack(spacing: 4) {
            Image(systemName: transportType.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(transportType == transportManager.primaryTransport ? transportColor : .secondary)
            
            Text(transportType.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(transportType == transportManager.primaryTransport ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(transportType == transportManager.primaryTransport ? transportColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(transportType == transportManager.primaryTransport ? transportColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Statistics View
    
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer Statistics")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            ForEach(transportManager.statistics.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { transportType in
                if let stats = transportManager.statistics[transportType] {
                    statisticRow(for: transportType, stats: stats)
                }
            }
        }
    }
    
    private func statisticRow(for transportType: TransportType, stats: TransportStatistics) -> some View {
        HStack {
            Image(systemName: transportType.icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(transportType.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.messagesSent) sent")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(ByteCountFormatter.string(fromByteCount: stats.bytesSent, countStyle: .file))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Transport Switching
    
    private var transportSwitchingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Override")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack {
                Button("Auto Select") {
                    // Reset to automatic transport selection
                    // TODO: Implement manual transport override
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12))
                
                Spacer()
                
                if transportManager.availableTransports.contains(.wifiDirect) && 
                   transportManager.primaryTransport != .wifiDirect {
                    Button("Force WiFi") {
                        // Force WiFi Direct transport
                        // TODO: Implement forced transport selection
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 12))
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var transportColor: Color {
        switch transportManager.primaryTransport {
        case .bluetooth:
            return .blue
        case .wifiDirect:
            return .green
        case .ultrasonic:
            return .purple
        case .lora:
            return .orange
        }
    }
    
    private var connectionStatusColor: Color {
        if transportManager.allPeers.isEmpty {
            return .gray
        } else if transportManager.isDiscovering {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Compact Transport Status

/// Compact version for showing in headers/toolbars
struct CompactTransportStatusView: View {
    @ObservedObject var transportManager: TransportManager
    @ObservedObject var fileTransferManager: FileTransferManager
    
    var body: some View {
        HStack(spacing: 6) {
            // Transport icon
            Image(systemName: transportManager.primaryTransport.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(transportColor)
            
            // Peer count
            Text("\(transportManager.allPeers.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            // Speed indicator for WiFi Direct
            if fileTransferManager.transportSpeedMultiplier > 1.0 {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(transportColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var transportColor: Color {
        switch transportManager.primaryTransport {
        case .bluetooth: return .blue
        case .wifiDirect: return .green
        case .ultrasonic: return .purple
        case .lora: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TransportStatusView(
            transportManager: TransportManager.shared,
            fileTransferManager: FileTransferManager.shared
        )
        
        CompactTransportStatusView(
            transportManager: TransportManager.shared,
            fileTransferManager: FileTransferManager.shared
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}