import Foundation
import CryptoKit

public struct PeerCommitment: Codable { public let version: Int; public let digest: Data }
public struct PeerHello: Codable { public let version: Int; public let publicKey: Data; public let nonce: Data }
public struct SealedPeerFrame: Codable { let sequence: Int; let combined: Data }
public enum PeerMessageKind: String, Codable { case approved, canvas, ink, preview, previewAck, revoke }
public struct PeerMessage: Codable {
    public let kind: PeerMessageKind
    public let payload: Data
    public init(_ kind: PeerMessageKind, payload: Data = Data()) { self.kind = kind; self.payload = payload }
}
/// An ephemeral, transcript-bound channel. Users compare the code on both devices before either grants input or preview.
public final class PairingChannel {
    private let privateKey = Curve25519.KeyAgreement.PrivateKey()
    private let nonce = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    private var peerCommitment: Data?
    private var key: SymmetricKey?
    private var sendSequence = 0
    private var receivedSequence = 0
    public let isHost: Bool
    public private(set) var comparisonCode: String?
    public init(isHost: Bool) { self.isHost = isHost }
    public var commitment: PeerCommitment {
        PeerCommitment(version: 2, digest: Data(SHA256.hash(data: privateKey.publicKey.rawRepresentation + nonce)))
    }
    public func acceptCommitment(_ commitment: PeerCommitment) throws {
        guard peerCommitment == nil, key == nil, commitment.version == 2, commitment.digest.count == 32 else { throw ModuleError.invalid("Invalid pairing commitment.") }
        peerCommitment = commitment.digest
    }
    public func reveal() throws -> PeerHello {
        guard peerCommitment != nil else { throw ModuleError.invalid("Both devices must commit before revealing their keys.") }
        return PeerHello(version: 2, publicKey: privateKey.publicKey.rawRepresentation, nonce: nonce)
    }
    public func accept(_ hello: PeerHello) throws {
        guard key == nil, let peerCommitment, hello.version == 2, hello.publicKey.count == 32, hello.nonce.count == 16,
              Data(SHA256.hash(data: hello.publicKey + hello.nonce)) == peerCommitment,
              hello.publicKey != privateKey.publicKey.rawRepresentation else { throw ModuleError.invalid("Invalid pairing handshake.") }
        let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: hello.publicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: remote)
        let own = privateKey.publicKey.rawRepresentation
        let transcript = isHost ? own + hello.publicKey + nonce + hello.nonce : hello.publicKey + own + hello.nonce + nonce
        let key = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: transcript,
            sharedInfo: Data("org.eidos.clips.ink.v2".utf8), outputByteCount: 32)
        self.key = key
        let codeBytes = HMAC<SHA256>.authenticationCode(for: Data("compare-on-both-devices".utf8), using: key)
        let value = codeBytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } % 1_000_000
        comparisonCode = String(format: "%06u", value)
    }
    public func seal(_ message: PeerMessage) throws -> Data {
        guard let key else { throw ModuleError.invalid("Pairing is incomplete.") }
        let payload = try JSONEncoder().encode(message)
        guard payload.count <= 350_000 else { throw ModuleError.invalid("Device message exceeds the size limit.") }
        sendSequence += 1
        let authenticated = Data("\(isHost ? "host" : "device"):\(sendSequence)".utf8)
        let sealed = try AES.GCM.seal(payload, using: key, authenticating: authenticated)
        guard let combined = sealed.combined else { throw ModuleError.invalid("Could not seal device message.") }
        return try JSONEncoder().encode(SealedPeerFrame(sequence: sendSequence, combined: combined))
    }
    public func open(_ data: Data) throws -> PeerMessage {
        guard data.count <= 500_000, let key else { throw ModuleError.invalid("Device message is unavailable or too large.") }
        let frame = try JSONDecoder().decode(SealedPeerFrame.self, from: data)
        guard frame.sequence == receivedSequence + 1 else { throw ModuleError.invalid("Repeated or missing device message.") }
        let authenticated = Data("\(isHost ? "device" : "host"):\(frame.sequence)".utf8)
        let payload = try AES.GCM.open(AES.GCM.SealedBox(combined: frame.combined), using: key, authenticating: authenticated)
        let message = try JSONDecoder().decode(PeerMessage.self, from: payload)
        receivedSequence = frame.sequence; return message
    }
}
public struct RemoteCanvas: Codable {
    public let snapshot: AnnotationSnapshot
    public let aspectRatio: Double
    public let acceptsInput: Bool
    public init(snapshot: AnnotationSnapshot, aspectRatio: Double, acceptsInput: Bool) {
        self.snapshot = snapshot; self.aspectRatio = aspectRatio; self.acceptsInput = acceptsInput
    }
}
