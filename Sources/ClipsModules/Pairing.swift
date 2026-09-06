import Foundation
import CryptoKit

public struct PeerHello: Codable { public let version: Int; public let publicKey: Data }
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
    private var key: SymmetricKey?
    private var sendSequence = 0
    private var receivedSequence = 0
    public let isHost: Bool
    public private(set) var comparisonCode: String?
    public init(isHost: Bool) { self.isHost = isHost }
    public var hello: PeerHello { PeerHello(version: 1, publicKey: privateKey.publicKey.rawRepresentation) }
    public func accept(_ hello: PeerHello) throws {
        guard key == nil, hello.version == 1, hello.publicKey.count == 32,
              hello.publicKey != privateKey.publicKey.rawRepresentation else { throw ModuleError.invalid("Invalid pairing handshake.") }
        let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: hello.publicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: remote)
        let own = privateKey.publicKey.rawRepresentation
        let transcript = isHost ? own + hello.publicKey : hello.publicKey + own
        let key = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: transcript,
            sharedInfo: Data("org.eidos.clips.ink.v1".utf8), outputByteCount: 32)
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
