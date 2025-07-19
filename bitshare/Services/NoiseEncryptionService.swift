//
// NoiseEncryptionService.swift
// bitshare
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//
// Implementation based on Jack's Noise Protocol implementation for bitchat compatibility

import Foundation
import CryptoKit
import os.log

// MARK: - Noise Message Types

enum NoiseMessageType: UInt8 {
    case handshake = 0
    case encrypted = 1
    case identityAnnounce = 2
    case channelInvite = 3
    case versionNegotiation = 4
    case rekeyRequest = 5
    case rekeyResponse = 6
}

// MARK: - Protocol Version Support

struct ProtocolVersion {
    let major: UInt8
    let minor: UInt8
    let patch: UInt8
    
    static let current = ProtocolVersion(major: 1, minor: 0, patch: 0)
    static let minimum = ProtocolVersion(major: 1, minor: 0, patch: 0)
    
    var isCompatible: Bool {
        return major == ProtocolVersion.current.major && 
               minor >= ProtocolVersion.minimum.minor
    }
    
    func encode() -> Data {
        return Data([major, minor, patch])
    }
    
    static func decode(from data: Data) -> ProtocolVersion? {
        guard data.count >= 3 else { return nil }
        return ProtocolVersion(major: data[0], minor: data[1], patch: data[2])
    }
}

struct NoiseMessage {
    let type: NoiseMessageType
    let sessionID: String
    let payload: Data
    
    func encode() -> Data {
        var data = Data()
        data.append(type.rawValue)
        let sessionIDData = sessionID.data(using: .utf8) ?? Data()
        data.append(UInt8(sessionIDData.count))
        data.append(sessionIDData)
        data.append(payload)
        return data
    }
    
    static func decode(from data: Data) -> NoiseMessage? {
        guard data.count >= 2 else { return nil }
        
        let type = NoiseMessageType(rawValue: data[0]) ?? .handshake
        let sessionIDLength = Int(data[1])
        
        guard data.count >= 2 + sessionIDLength else { return nil }
        
        let sessionIDData = data[2..<(2 + sessionIDLength)]
        let sessionID = String(data: sessionIDData, encoding: .utf8) ?? ""
        
        let payload = data[(2 + sessionIDLength)...]
        
        return NoiseMessage(type: type, sessionID: sessionID, payload: Data(payload))
    }
}

// MARK: - Noise Session Management

class NoiseSession {
    let sessionID: String
    let peerID: String
    private var ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey
    private var ephemeralPublicKey: Curve25519.KeyAgreement.PublicKey
    private var peerEphemeralKey: Curve25519.KeyAgreement.PublicKey?
    private var sharedSecret: SymmetricKey?
    private var isInitiator: Bool
    private var handshakeComplete: Bool = false
    private var lastActivity: Date = Date()
    private var rekeyTimer: Timer?
    
    // Enhanced security features
    private var protocolVersion: ProtocolVersion
    private var versionNegotiated: Bool
    private var rekeyInProgress: Bool = false
    private var messageCounter: UInt64 = 0
    private var ephemeralKeyRotationCount: UInt32 = 0
    
    // Forward secrecy enhancement
    private var previousKeys: [SymmetricKey] = []
    private let maxPreviousKeys = 10
    
    init(sessionID: String, peerID: String, isInitiator: Bool) {
        self.sessionID = sessionID
        self.peerID = peerID
        self.isInitiator = isInitiator
        
        // Generate ephemeral keys for this session
        self.ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        self.ephemeralPublicKey = ephemeralPrivateKey.publicKey
        
        // Start rekey timer for 60 seconds (matching Jack's implementation)
        startRekeyTimer()
        
        // Initialize version negotiation state
        self.protocolVersion = ProtocolVersion.current
        self.versionNegotiated = false
    }
    
    deinit {
        rekeyTimer?.invalidate()
    }
    
    private func startRekeyTimer() {
        rekeyTimer?.invalidate()
        rekeyTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.performRekey()
        }
    }
    
    private func performRekey() {
        guard !rekeyInProgress else { return }
        
        rekeyInProgress = true
        
        // Store previous key for forward secrecy
        if let currentKey = sharedSecret {
            previousKeys.append(currentKey)
            if previousKeys.count > maxPreviousKeys {
                previousKeys.removeFirst()
            }
        }
        
        // Generate new ephemeral keys
        ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        ephemeralPublicKey = ephemeralPrivateKey.publicKey
        ephemeralKeyRotationCount += 1
        
        // Clear old shared secret
        sharedSecret = nil
        handshakeComplete = false
        
        // Reset message counter
        messageCounter = 0
        
        // Restart rekey timer
        startRekeyTimer()
        
        rekeyInProgress = false
        
        os_log("Noise session rekey performed for peer %@ (rotation #%d)", log: .default, type: .info, peerID, ephemeralKeyRotationCount)
    }
    
    func getEphemeralPublicKey() -> Data {
        return ephemeralPublicKey.rawRepresentation
    }
    
    func processHandshake(_ peerEphemeralKeyData: Data) throws {
        // Store peer's ephemeral key
        peerEphemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerEphemeralKeyData)
        
        // Generate shared secret using our ephemeral private key and peer's ephemeral public key
        guard let peerKey = peerEphemeralKey else {
            throw NoiseEncryptionError.handshakeFailed
        }
        
        let rawSharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: peerKey)
        
        // Derive symmetric key using HKDF (matching Jack's approach)
        sharedSecret = rawSharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "noise-bitshare-v1".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        handshakeComplete = true
        lastActivity = Date()
        
        os_log("Noise handshake completed for peer %@", log: .default, type: .info, peerID)
    }
    
    func encrypt(_ data: Data) throws -> Data {
        guard handshakeComplete, let key = sharedSecret else {
            throw NoiseEncryptionError.sessionNotReady
        }
        
        // Increment message counter for replay protection
        messageCounter += 1
        
        // Add message counter to additional data for authentication
        let additionalData = withUnsafeBytes(of: messageCounter.bigEndian) { Data($0) }
        
        let sealedBox = try AES.GCM.seal(data, using: key, authenticating: additionalData)
        lastActivity = Date()
        
        // Prepend message counter to encrypted data
        var result = additionalData
        result.append(sealedBox.combined ?? Data())
        
        return result
    }
    
    func decrypt(_ data: Data) throws -> Data {
        guard handshakeComplete, let key = sharedSecret else {
            throw NoiseEncryptionError.sessionNotReady
        }
        
        // Extract message counter from the beginning of data
        guard data.count >= 8 else {
            throw NoiseEncryptionError.invalidMessage
        }
        
        let counterData = data[0..<8]
        let encryptedData = data[8...]
        
        let messageCounter = counterData.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        
        // Basic replay protection (in production, would need more sophisticated tracking)
        guard messageCounter > self.messageCounter else {
            throw NoiseEncryptionError.replayAttack
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: Data(encryptedData))
        let decrypted = try AES.GCM.open(sealedBox, using: key, authenticating: counterData)
        
        // Update our message counter
        self.messageCounter = messageCounter
        lastActivity = Date()
        
        return decrypted
    }
    
    var isExpired: Bool {
        return Date().timeIntervalSince(lastActivity) > 300 // 5 minutes
    }
    
    var isReady: Bool {
        return handshakeComplete && sharedSecret != nil && versionNegotiated
    }
    
    func setProtocolVersion(_ version: ProtocolVersion) {
        self.protocolVersion = version
        self.versionNegotiated = true
    }
    
    func getProtocolVersion() -> ProtocolVersion {
        return protocolVersion
    }
    
    func getEphemeralKeyRotationCount() -> UInt32 {
        return ephemeralKeyRotationCount
    }
    
    // Enhanced forward secrecy - attempt to decrypt with previous keys
    func tryDecryptWithPreviousKeys(_ data: Data) -> Data? {
        for previousKey in previousKeys.reversed() {
            if let decrypted = try? decryptWithKey(data, key: previousKey) {
                return decrypted
            }
        }
        return nil
    }
    
    private func decryptWithKey(_ data: Data, key: SymmetricKey) throws -> Data {
        guard data.count >= 8 else {
            throw NoiseEncryptionError.invalidMessage
        }
        
        let counterData = data[0..<8]
        let encryptedData = data[8...]
        
        let sealedBox = try AES.GCM.SealedBox(combined: Data(encryptedData))
        return try AES.GCM.open(sealedBox, using: key, authenticating: counterData)
    }
}

// MARK: - Noise Encryption Service

class NoiseEncryptionService {
    
    // Static identity key (persistent across sessions)
    private let staticIdentityKey: Curve25519.KeyAgreement.PrivateKey
    public let staticIdentityPublicKey: Curve25519.KeyAgreement.PublicKey
    
    // Session management
    private var sessions: [String: NoiseSession] = [:]
    private let sessionQueue = DispatchQueue(label: "noise.session.queue", attributes: .concurrent)
    
    // Peer tracking
    private var peerFingerprints: [String: String] = [:]
    private var fingerprintToPeerID: [String: String] = [:]
    
    // Rate limiting (matching Jack's security features)
    private var handshakeAttempts: [String: (count: Int, lastAttempt: Date)] = [:]
    private var messageAttempts: [String: (count: Int, lastAttempt: Date)] = [:]
    private let maxHandshakeAttempts = 10
    private let maxMessageAttempts = 100
    private let rateLimitWindow: TimeInterval = 60.0
    
    // Callbacks for authentication events
    var onPeerAuthenticated: ((String) -> Void)?
    var onSessionEstablished: ((String) -> Void)?
    var onSessionExpired: ((String) -> Void)?
    var onVersionNegotiated: ((String, ProtocolVersion) -> Void)?
    var onRekeyComplete: ((String) -> Void)?
    
    // Enhanced security features
    private var supportedVersions: [ProtocolVersion] = [ProtocolVersion.current]
    private var peerVersions: [String: ProtocolVersion] = [:]
    private var rekeyRequests: [String: Date] = [:]
    private let maxRekeyRequests = 5
    private let rekeyWindow: TimeInterval = 300.0 // 5 minutes
    
    init() {
        // Load or generate static identity key
        if let keyData = KeychainManager.shared.getIdentityKey(forKey: "noise"),
           let loadedKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData) {
            self.staticIdentityKey = loadedKey
        } else {
            // Generate new identity key
            self.staticIdentityKey = Curve25519.KeyAgreement.PrivateKey()
            _ = KeychainManager.shared.saveIdentityKey(staticIdentityKey.rawRepresentation, forKey: "noise")
        }
        
        self.staticIdentityPublicKey = staticIdentityKey.publicKey
        
        // Start session cleanup timer
        startSessionCleanupTimer()
        
        os_log("NoiseEncryptionService initialized", log: .default, type: .info)
    }
    
    // MARK: - Version Negotiation
    
    func initiateVersionNegotiation(with peerID: String) -> NoiseMessage? {
        let versionPayload = ProtocolVersion.current.encode()
        return NoiseMessage(
            type: .versionNegotiation,
            sessionID: UUID().uuidString,
            payload: versionPayload
        )
    }
    
    func processVersionNegotiation(_ message: NoiseMessage, from peerID: String) -> NoiseMessage? {
        guard let peerVersion = ProtocolVersion.decode(from: message.payload) else {
            return nil
        }
        
        // Store peer version
        peerVersions[peerID] = peerVersion
        
        // Check compatibility
        if peerVersion.isCompatible {
            // Update session with negotiated version
            if let session = sessions[peerID] {
                session.setProtocolVersion(peerVersion)
            }
            
            onVersionNegotiated?(peerID, peerVersion)
            
            // Send our version back
            let responsePayload = ProtocolVersion.current.encode()
            return NoiseMessage(
                type: .versionNegotiation,
                sessionID: message.sessionID,
                payload: responsePayload
            )
        } else {
            os_log("Incompatible version from peer %@: %d.%d.%d", log: .default, type: .error, peerID, peerVersion.major, peerVersion.minor, peerVersion.patch)
            return nil
        }
    }
    
    // MARK: - Session Management
    
    func initiateHandshake(with peerID: String) -> NoiseMessage? {
        guard checkRateLimit(for: peerID, type: .handshake) else {
            os_log("Rate limit exceeded for handshake with peer %@", log: .default, type: .error, peerID)
            return nil
        }
        
        let sessionID = UUID().uuidString
        let session = NoiseSession(sessionID: sessionID, peerID: peerID, isInitiator: true)
        
        return sessionQueue.sync(flags: .barrier) {
            sessions[peerID] = session
            
            // Create handshake message with our ephemeral public key
            let message = NoiseMessage(
                type: .handshake,
                sessionID: sessionID,
                payload: session.getEphemeralPublicKey()
            )
            
            os_log("Initiated handshake with peer %@", log: .default, type: .info, peerID)
            return message
        }
    }
    
    func processHandshakeMessage(_ message: NoiseMessage, from peerID: String) -> NoiseMessage? {
        guard checkRateLimit(for: peerID, type: .handshake) else {
            os_log("Rate limit exceeded for handshake processing from peer %@", log: .default, type: .error, peerID)
            return nil
        }
        
        return sessionQueue.sync(flags: .barrier) {
            if let existingSession = sessions[peerID] {
                // Complete existing handshake
                do {
                    try existingSession.processHandshake(message.payload)
                    
                    // Set version if negotiated
                    if let peerVersion = peerVersions[peerID] {
                        existingSession.setProtocolVersion(peerVersion)
                    }
                    
                    onSessionEstablished?(peerID)
                    return nil // Handshake complete
                } catch {
                    os_log("Failed to complete handshake with peer %@: %@", log: .default, type: .error, peerID, error.localizedDescription)
                    return nil
                }
            } else {
                // Create new session and respond
                let session = NoiseSession(sessionID: message.sessionID, peerID: peerID, isInitiator: false)
                sessions[peerID] = session
                
                do {
                    try session.processHandshake(message.payload)
                    
                    // Set version if negotiated
                    if let peerVersion = peerVersions[peerID] {
                        session.setProtocolVersion(peerVersion)
                    }
                    
                    onSessionEstablished?(peerID)
                    
                    // Send our ephemeral key back
                    let response = NoiseMessage(
                        type: .handshake,
                        sessionID: message.sessionID,
                        payload: session.getEphemeralPublicKey()
                    )
                    
                    os_log("Processed handshake from peer %@", log: .default, type: .info, peerID)
                    return response
                } catch {
                    sessions.removeValue(forKey: peerID)
                    os_log("Failed to process handshake from peer %@: %@", log: .default, type: .error, peerID, error.localizedDescription)
                    return nil
                }
            }
        }
    }
    
    // MARK: - Message Encryption/Decryption
    
    func encryptMessage(_ data: Data, for peerID: String) -> NoiseMessage? {
        guard checkRateLimit(for: peerID, type: .message) else {
            os_log("Rate limit exceeded for message encryption to peer %@", log: .default, type: .error, peerID)
            return nil
        }
        
        return sessionQueue.sync {
            guard let session = sessions[peerID], session.isReady else {
                os_log("No ready session for peer %@", log: .default, type: .error, peerID)
                return nil
            }
            
            do {
                let encryptedData = try session.encrypt(data)
                return NoiseMessage(
                    type: .encrypted,
                    sessionID: session.sessionID,
                    payload: encryptedData
                )
            } catch {
                os_log("Failed to encrypt message for peer %@: %@", log: .default, type: .error, peerID, error.localizedDescription)
                return nil
            }
        }
    }
    
    func decryptMessage(_ message: NoiseMessage, from peerID: String) -> Data? {
        guard checkRateLimit(for: peerID, type: .message) else {
            os_log("Rate limit exceeded for message decryption from peer %@", log: .default, type: .error, peerID)
            return nil
        }
        
        return sessionQueue.sync {
            guard let session = sessions[peerID], session.isReady else {
                os_log("No ready session for peer %@", log: .default, type: .error, peerID)
                return nil
            }
            
            do {
                return try session.decrypt(message.payload)
            } catch {
                // Try to decrypt with previous keys for forward secrecy
                if let decrypted = session.tryDecryptWithPreviousKeys(message.payload) {
                    os_log("Decrypted message from peer %@ using previous key", log: .default, type: .info, peerID)
                    return decrypted
                }
                
                os_log("Failed to decrypt message from peer %@: %@", log: .default, type: .error, peerID, error.localizedDescription)
                return nil
            }
        }
    }
    
    // MARK: - Peer Management
    
    func addPeerFingerprint(_ peerID: String, publicKey: Data) {
        let fingerprint = SHA256.hash(data: publicKey)
        let fingerprintString = fingerprint.compactMap { String(format: "%02x", $0) }.joined()
        
        sessionQueue.sync(flags: .barrier) {
            peerFingerprints[peerID] = fingerprintString
            fingerprintToPeerID[fingerprintString] = peerID
        }
        
        onPeerAuthenticated?(peerID)
        os_log("Added peer fingerprint for %@", log: .default, type: .info, peerID)
    }
    
    func getPeerFingerprint(_ peerID: String) -> String? {
        return sessionQueue.sync {
            return peerFingerprints[peerID]
        }
    }
    
    func hasSession(with peerID: String) -> Bool {
        return sessionQueue.sync {
            return sessions[peerID]?.isReady ?? false
        }
    }
    
    // MARK: - Rate Limiting
    
    private enum RateLimitType {
        case handshake
        case message
    }
    
    private func checkRateLimit(for peerID: String, type: RateLimitType) -> Bool {
        let now = Date()
        
        switch type {
        case .handshake:
            if let attempts = handshakeAttempts[peerID] {
                if now.timeIntervalSince(attempts.lastAttempt) > rateLimitWindow {
                    handshakeAttempts[peerID] = (count: 1, lastAttempt: now)
                    return true
                } else if attempts.count >= maxHandshakeAttempts {
                    return false
                } else {
                    handshakeAttempts[peerID] = (count: attempts.count + 1, lastAttempt: now)
                    return true
                }
            } else {
                handshakeAttempts[peerID] = (count: 1, lastAttempt: now)
                return true
            }
            
        case .message:
            if let attempts = messageAttempts[peerID] {
                if now.timeIntervalSince(attempts.lastAttempt) > rateLimitWindow {
                    messageAttempts[peerID] = (count: 1, lastAttempt: now)
                    return true
                } else if attempts.count >= maxMessageAttempts {
                    return false
                } else {
                    messageAttempts[peerID] = (count: attempts.count + 1, lastAttempt: now)
                    return true
                }
            } else {
                messageAttempts[peerID] = (count: 1, lastAttempt: now)
                return true
            }
        }
    }
    
    // MARK: - Session Cleanup
    
    private func startSessionCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredSessions()
        }
    }
    
    private func cleanupExpiredSessions() {
        sessionQueue.sync(flags: .barrier) {
            let expiredPeers = sessions.filter { $0.value.isExpired }.map { $0.key }
            
            for peerID in expiredPeers {
                sessions.removeValue(forKey: peerID)
                peerVersions.removeValue(forKey: peerID)
                onSessionExpired?(peerID)
                os_log("Cleaned up expired session for peer %@", log: .default, type: .info, peerID)
            }
            
            // Clean up old rekey requests
            let now = Date()
            rekeyRequests = rekeyRequests.filter { now.timeIntervalSince($0.value) < rekeyWindow }
        }
    }
    
    // MARK: - Emergency Functions
    
    // MARK: - Rekey Management
    
    func initiateRekey(with peerID: String) -> NoiseMessage? {
        guard let session = sessions[peerID] else { return nil }
        
        // Check rekey rate limiting
        let now = Date()
        if let lastRekey = rekeyRequests[peerID] {
            if now.timeIntervalSince(lastRekey) < rekeyWindow {
                os_log("Rekey rate limit exceeded for peer %@", log: .default, type: .error, peerID)
                return nil
            }
        }
        
        rekeyRequests[peerID] = now
        
        // Create rekey request with new ephemeral key
        let newEphemeralKey = Curve25519.KeyAgreement.PrivateKey()
        let rekeyPayload = newEphemeralKey.publicKey.rawRepresentation
        
        return NoiseMessage(
            type: .rekeyRequest,
            sessionID: session.sessionID,
            payload: rekeyPayload
        )
    }
    
    func processRekeyRequest(_ message: NoiseMessage, from peerID: String) -> NoiseMessage? {
        guard let session = sessions[peerID] else { return nil }
        
        // Generate new ephemeral key and create response
        let newEphemeralKey = Curve25519.KeyAgreement.PrivateKey()
        let responsePayload = newEphemeralKey.publicKey.rawRepresentation
        
        // Trigger rekey on our session
        DispatchQueue.main.async {
            session.performRekey()
        }
        
        return NoiseMessage(
            type: .rekeyResponse,
            sessionID: message.sessionID,
            payload: responsePayload
        )
    }
    
    func processRekeyResponse(_ message: NoiseMessage, from peerID: String) {
        guard let session = sessions[peerID] else { return }
        
        // Complete rekey process
        do {
            try session.processHandshake(message.payload)
            onRekeyComplete?(peerID)
            os_log("Rekey completed for peer %@", log: .default, type: .info, peerID)
        } catch {
            os_log("Failed to complete rekey for peer %@: %@", log: .default, type: .error, peerID, error.localizedDescription)
        }
    }
    
    // MARK: - Enhanced Session Management
    
    func clearAllSessions() {
        sessionQueue.sync(flags: .barrier) {
            sessions.removeAll()
            peerFingerprints.removeAll()
            fingerprintToPeerID.removeAll()
            handshakeAttempts.removeAll()
            messageAttempts.removeAll()
            peerVersions.removeAll()
            rekeyRequests.removeAll()
        }
        
        os_log("Cleared all Noise sessions", log: .default, type: .info)
    }
    
    func regenerateIdentity() {
        let newKey = Curve25519.KeyAgreement.PrivateKey()
        _ = KeychainManager.shared.saveIdentityKey(newKey.rawRepresentation, forKey: "noise")
        
        // Clear all existing sessions since identity changed
        clearAllSessions()
        
        os_log("Regenerated Noise identity key", log: .default, type: .info)
    }
    
    // MARK: - Protocol Version Management
    
    func getSupportedVersions() -> [ProtocolVersion] {
        return supportedVersions
    }
    
    func getPeerVersion(_ peerID: String) -> ProtocolVersion? {
        return peerVersions[peerID]
    }
    
    func isVersionCompatible(_ version: ProtocolVersion) -> Bool {
        return version.isCompatible
    }
    
    // MARK: - Enhanced Security Functions
    
    func getSessionStatistics(_ peerID: String) -> (rotationCount: UInt32, messageCount: UInt64)? {
        guard let session = sessions[peerID] else { return nil }
        return (session.getEphemeralKeyRotationCount(), session.messageCounter)
    }
    
    func emergencyWipe() {
        // Securely wipe all cryptographic material
        clearAllSessions()
        
        // Regenerate identity
        regenerateIdentity()
        
        // Clear keychain
        KeychainManager.shared.clearAllKeys()
        
        os_log("Emergency wipe completed", log: .default, type: .info)
    }
}

// MARK: - Error Types

enum NoiseEncryptionError: Error {
    case sessionNotReady
    case handshakeFailed
    case encryptionFailed
    case decryptionFailed
    case rateLimitExceeded
    case invalidMessage
    case versionNegotiationFailed
    case incompatibleVersion
    case replayAttack
    case rekeyInProgress
}

