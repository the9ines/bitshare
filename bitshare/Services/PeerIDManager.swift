//
// PeerIDManager.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//
// Enhanced peer ID management with ephemeral rotation for privacy

import Foundation
import CryptoKit
import os.log

// MARK: - Ephemeral Peer ID Management

/// Manages ephemeral peer IDs that rotate every 5-15 minutes for enhanced privacy
class PeerIDManager: ObservableObject {
    static let shared = PeerIDManager()
    
    // MARK: - Published Properties
    @Published var currentPeerID: String = ""
    @Published var peerNickname: String = ""
    @Published var rotationCount: UInt32 = 0
    
    // MARK: - Private Properties
    private var staticIdentityKey: Curve25519.KeyAgreement.PrivateKey
    private var currentEphemeralKey: Curve25519.KeyAgreement.PrivateKey
    private var rotationTimer: Timer?
    private var rotationInterval: TimeInterval
    private var lastRotationTime: Date = Date()
    
    // Peer tracking
    private var peerIDHistory: [String] = []
    private var peerIDToStaticKey: [String: Data] = [:]
    private var staticKeyToPeerID: [Data: String] = [:]
    
    // Privacy settings
    private let minRotationInterval: TimeInterval = 5 * 60  // 5 minutes
    private let maxRotationInterval: TimeInterval = 15 * 60 // 15 minutes
    private let maxHistorySize = 100
    
    // Callbacks
    var onPeerIDRotated: ((String, String) -> Void)? // (oldID, newID)
    var onPeerIDMapped: ((String, Data) -> Void)?    // (peerID, staticKey)
    
    // MARK: - Initialization
    
    private init() {
        // Load or generate static identity key
        if let keyData = KeychainManager.shared.getIdentityKey(forKey: "static_identity"),
           let loadedKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData) {
            self.staticIdentityKey = loadedKey
        } else {
            self.staticIdentityKey = Curve25519.KeyAgreement.PrivateKey()
            _ = KeychainManager.shared.saveIdentityKey(staticIdentityKey.rawRepresentation, forKey: "static_identity")
        }
        
        // Generate initial ephemeral key and peer ID
        self.currentEphemeralKey = Curve25519.KeyAgreement.PrivateKey()
        self.rotationInterval = generateRandomInterval()
        
        // Load saved nickname or generate default
        self.peerNickname = UserDefaults.standard.string(forKey: "peer_nickname") ?? generateDefaultNickname()
        
        // Generate initial peer ID
        generateNewPeerID()
        
        // Start rotation timer
        startRotationTimer()
        
        os_log("PeerIDManager initialized with rotation interval: %d seconds", log: .default, type: .info, Int(rotationInterval))
    }
    
    // MARK: - Peer ID Generation
    
    private func generateNewPeerID() {
        let oldPeerID = currentPeerID
        
        // Generate new ephemeral key
        currentEphemeralKey = Curve25519.KeyAgreement.PrivateKey()
        
        // Create peer ID by combining static and ephemeral keys
        let combinedKeyData = staticIdentityKey.publicKey.rawRepresentation + currentEphemeralKey.publicKey.rawRepresentation
        let peerIDHash = SHA256.hash(data: combinedKeyData)
        
        // Create human-readable peer ID (first 12 chars of hash)
        let peerIDString = peerIDHash.compactMap { String(format: "%02x", $0) }.joined()
        currentPeerID = String(peerIDString.prefix(12))
        
        // Update tracking
        peerIDHistory.append(currentPeerID)
        if peerIDHistory.count > maxHistorySize {
            peerIDHistory.removeFirst()
        }
        
        rotationCount += 1
        lastRotationTime = Date()
        
        // Map peer ID to static key
        peerIDToStaticKey[currentPeerID] = staticIdentityKey.publicKey.rawRepresentation
        staticKeyToPeerID[staticIdentityKey.publicKey.rawRepresentation] = currentPeerID
        
        // Notify listeners
        if !oldPeerID.isEmpty {
            onPeerIDRotated?(oldPeerID, currentPeerID)
        }
        
        onPeerIDMapped?(currentPeerID, staticIdentityKey.publicKey.rawRepresentation)
        
        os_log("Generated new peer ID: %@ (rotation #%d)", log: .default, type: .info, currentPeerID, rotationCount)
    }
    
    // MARK: - Rotation Management
    
    private func startRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: false) { [weak self] _ in
            self?.performRotation()
        }
    }
    
    private func performRotation() {
        generateNewPeerID()
        
        // Generate new random interval for next rotation
        rotationInterval = generateRandomInterval()
        
        // Restart timer with new interval
        startRotationTimer()
        
        os_log("Peer ID rotation completed. Next rotation in %d seconds", log: .default, type: .info, Int(rotationInterval))
    }
    
    private func generateRandomInterval() -> TimeInterval {
        return TimeInterval.random(in: minRotationInterval...maxRotationInterval)
    }
    
    // MARK: - Peer Management
    
    func mapPeerID(_ peerID: String, to staticKey: Data) {
        peerIDToStaticKey[peerID] = staticKey
        staticKeyToPeerID[staticKey] = peerID
        onPeerIDMapped?(peerID, staticKey)
        
        os_log("Mapped peer ID %@ to static key", log: .default, type: .info, peerID)
    }
    
    func getStaticKey(for peerID: String) -> Data? {
        return peerIDToStaticKey[peerID]
    }
    
    func getPeerID(for staticKey: Data) -> String? {
        return staticKeyToPeerID[staticKey]
    }
    
    func isKnownPeerID(_ peerID: String) -> Bool {
        return peerIDToStaticKey[peerID] != nil
    }
    
    func getPeerIDHistory() -> [String] {
        return peerIDHistory
    }
    
    // MARK: - Nickname Management
    
    func updateNickname(_ nickname: String) {
        peerNickname = nickname
        UserDefaults.standard.set(nickname, forKey: "peer_nickname")
        os_log("Updated peer nickname to: %@", log: .default, type: .info, nickname)
    }
    
    private func generateDefaultNickname() -> String {
        let adjectives = ["Swift", "Secure", "Private", "Anonymous", "Encrypted", "Decentralized"]
        let nouns = ["Peer", "Node", "Device", "Client", "Station", "Terminal"]
        
        let randomAdjective = adjectives.randomElement() ?? "Unknown"
        let randomNoun = nouns.randomElement() ?? "Peer"
        let randomNumber = Int.random(in: 100...999)
        
        return "\(randomAdjective)\(randomNoun)\(randomNumber)"
    }
    
    // MARK: - Identity Management
    
    func getStaticIdentityKey() -> Curve25519.KeyAgreement.PrivateKey {
        return staticIdentityKey
    }
    
    func getCurrentEphemeralKey() -> Curve25519.KeyAgreement.PrivateKey {
        return currentEphemeralKey
    }
    
    func getPublicIdentityFingerprint() -> String {
        let fingerprint = SHA256.hash(data: staticIdentityKey.publicKey.rawRepresentation)
        return fingerprint.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Rotation Control
    
    func forceRotation() {
        performRotation()
    }
    
    func pauseRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        os_log("Peer ID rotation paused", log: .default, type: .info)
    }
    
    func resumeRotation() {
        guard rotationTimer == nil else { return }
        startRotationTimer()
        os_log("Peer ID rotation resumed", log: .default, type: .info)
    }
    
    func setRotationInterval(min: TimeInterval, max: TimeInterval) {
        guard min >= 60 && max <= 3600 && min < max else { return } // Sanity check
        
        self.rotationInterval = TimeInterval.random(in: min...max)
        
        // Restart timer with new interval
        startRotationTimer()
        
        os_log("Updated rotation interval: %d-%d seconds", log: .default, type: .info, Int(min), Int(max))
    }
    
    // MARK: - Statistics
    
    func getRotationStatistics() -> (currentPeerID: String, rotationCount: UInt32, lastRotation: Date, nextRotation: Date) {
        let nextRotation = lastRotationTime.addingTimeInterval(rotationInterval)
        return (currentPeerID, rotationCount, lastRotationTime, nextRotation)
    }
    
    func getTimeUntilNextRotation() -> TimeInterval {
        let nextRotation = lastRotationTime.addingTimeInterval(rotationInterval)
        return max(0, nextRotation.timeIntervalSinceNow)
    }
    
    // MARK: - Emergency Functions
    
    func emergencyRotation() {
        // Immediately rotate peer ID
        performRotation()
        
        // Set shorter rotation interval for enhanced privacy
        setRotationInterval(min: 60, max: 300) // 1-5 minutes
        
        os_log("Emergency peer ID rotation performed", log: .default, type: .info)
    }
    
    func resetIdentity() {
        // Generate new static identity key
        staticIdentityKey = Curve25519.KeyAgreement.PrivateKey()
        _ = KeychainManager.shared.saveIdentityKey(staticIdentityKey.rawRepresentation, forKey: "static_identity")
        
        // Clear all peer mappings
        peerIDToStaticKey.removeAll()
        staticKeyToPeerID.removeAll()
        peerIDHistory.removeAll()
        
        // Generate new peer ID
        rotationCount = 0
        generateNewPeerID()
        
        os_log("Identity reset completed", log: .default, type: .info)
    }
    
    deinit {
        rotationTimer?.invalidate()
    }
}

// MARK: - Peer Identity Verification

extension PeerIDManager {
    
    /// Verify that a peer ID corresponds to a known static identity
    func verifyPeerIdentity(_ peerID: String, staticKey: Data) -> Bool {
        guard let knownStaticKey = peerIDToStaticKey[peerID] else {
            return false
        }
        
        return knownStaticKey == staticKey
    }
    
    /// Create a verifiable identity proof for another peer
    func createIdentityProof(for peerID: String) -> Data? {
        let timestamp = Date().timeIntervalSince1970
        let proofData = currentPeerID.data(using: .utf8)! + 
                       peerID.data(using: .utf8)! + 
                       withUnsafeBytes(of: timestamp) { Data($0) }
        
        do {
            let signature = try staticIdentityKey.signature(for: proofData)
            return signature
        } catch {
            os_log("Failed to create identity proof: %@", log: .default, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    /// Verify an identity proof from another peer
    func verifyIdentityProof(_ proof: Data, from peerID: String, staticKey: Data) -> Bool {
        guard let staticKeyObj = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: staticKey) else {
            return false
        }
        
        let timestamp = Date().timeIntervalSince1970
        let proofData = peerID.data(using: .utf8)! + 
                       currentPeerID.data(using: .utf8)! + 
                       withUnsafeBytes(of: timestamp) { Data($0) }
        
        do {
            return try staticKeyObj.isValidSignature(proof, for: proofData)
        } catch {
            os_log("Failed to verify identity proof: %@", log: .default, type: .error, error.localizedDescription)
            return false
        }
    }
}