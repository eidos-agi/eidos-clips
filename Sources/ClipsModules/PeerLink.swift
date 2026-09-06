import Foundation
import MultipeerConnectivity

private final class PeerIngress: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = 0
    func claim() -> Bool { lock.lock(); defer { lock.unlock() }; guard pending < 32 else { return false }; pending += 1; return true }
    func release() { lock.lock(); pending -= 1; lock.unlock() }
}
/// One ephemeral nearby device, reliable bounded messages, encrypted transport plus an authenticated app channel.
/// No recording commands, shell, filesystem or account authority are part of this protocol.
@MainActor public final class PeerLink: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    public var changed: (() -> Void)?
    public var received: ((PeerMessage) -> Void)?
    public private(set) var status = "Disconnected"
    public private(set) var comparisonCode: String?
    public private(set) var connected = false
    public private(set) var approved = false
    public private(set) var localApproved = false
    private var remoteApproved = false
    private var channel: PairingChannel?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var chosen: MCPeerID?
    private var timeout: Task<Void, Never>?
    private var role = false
    private var messageWindow = ProcessInfo.processInfo.systemUptime
    private var messageCount = 0
    private nonisolated let ingress = PeerIngress()
    public override init() { super.init() }
    public func start(host: Bool) {
        stop(); role = host; channel = PairingChannel(isHost: host)
        let peer = MCPeerID(displayName: (host ? "Clips-" : "Draw-") + String(UUID().uuidString.prefix(6)))
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self; self.session = session
        if host {
            let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["v": "1"], serviceType: "eidos-clips")
            advertiser.delegate = self; self.advertiser = advertiser; advertiser.startAdvertisingPeer()
        } else {
            let browser = MCNearbyServiceBrowser(peer: peer, serviceType: "eidos-clips")
            browser.delegate = self; self.browser = browser; browser.startBrowsingForPeers()
        }
        status = host ? "Waiting for a drawing device…" : "Looking for Clips on your Mac…"; changed?()
        timeout = Task { try? await Task.sleep(nanoseconds: 90_000_000_000); guard !Task.isCancelled, !approved else { return }; stop(); status = "Pairing timed out. Try again."; changed?() }
    }
    public func approve() {
        guard comparisonCode != nil, connected, !localApproved else { return }
        localApproved = true
        do { try send(.init(.approved), requiresApproval: false); updateApproval() }
        catch { fail() }
    }
    public func stop() {
        timeout?.cancel(); timeout = nil; advertiser?.stopAdvertisingPeer(); browser?.stopBrowsingForPeers()
        advertiser = nil; browser = nil; session?.disconnect(); session = nil; channel = nil; chosen = nil
        approved = false; localApproved = false; remoteApproved = false; connected = false; comparisonCode = nil
        status = "Disconnected"; changed?()
    }
    public func send(_ message: PeerMessage) throws { try send(message, requiresApproval: true) }
    private func send(_ message: PeerMessage, requiresApproval: Bool) throws {
        guard (!requiresApproval || approved), let session, let chosen, let channel, connected else { throw ModuleError.invalid("Drawing device is not paired.") }
        try session.send(channel.seal(message), toPeers: [chosen], with: .reliable)
    }
    private func updateApproval() {
        approved = localApproved && remoteApproved
        status = approved ? "Connected · drawing only" : localApproved ? "Waiting for confirmation on the other device…" : "Compare this code on both devices."
        if approved { timeout?.cancel(); advertiser?.stopAdvertisingPeer(); browser?.stopBrowsingForPeers(); DiagnosticLog.shared.record(.deviceConnected) }
        changed?()
    }
    private func fail() { DiagnosticLog.shared.record(.pairingRejected); stop(); status = "Connection rejected. Pair again."; changed?() }
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard self.session === session else { return }
            if state == .connected {
                guard self.chosen == peerID, let channel else { fail(); return }
                connected = true
                do { try session.send(JSONEncoder().encode(channel.hello), toPeers: [peerID], with: .reliable) } catch { fail() }
            } else if state == .notConnected { DiagnosticLog.shared.record(.deviceDisconnected); stop() }
            changed?()
        }
    }
    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= 500_000, ingress.claim() else { return }
        Task { @MainActor in
            defer { ingress.release() }
            guard self.session === session, chosen == peerID, let channel else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if now - messageWindow > 1 { messageWindow = now; messageCount = 0 }; messageCount += 1
            guard messageCount <= 240 else { fail(); return }
            do {
                if comparisonCode == nil {
                    guard data.count <= 1024 else { throw ModuleError.invalid("Handshake too large.") }
                    try channel.accept(JSONDecoder().decode(PeerHello.self, from: data)); comparisonCode = channel.comparisonCode
                    status = "Compare this code on both devices."; changed?(); return
                }
                let message = try channel.open(data)
                if message.kind == .approved { remoteApproved = true; updateApproval(); return }
                guard approved else { throw ModuleError.invalid("Device is not approved.") }
                if message.kind == .revoke { stop(); return }
                guard role ? [.ink, .previewAck].contains(message.kind) : [.canvas, .preview].contains(message.kind) else { throw ModuleError.invalid("Device requested an unavailable capability.") }
                received?(message)
            } catch { fail() }
        }
    }
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            guard self.advertiser === advertiser, chosen == nil, let session, context == Data("ink-v1".utf8) else { invitationHandler(false, nil); return }
            chosen = peerID; invitationHandler(true, session)
        }
    }
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard self.browser === browser, chosen == nil, info?["v"] == "1", let session else { return }
            chosen = peerID; browser.invitePeer(peerID, to: session, withContext: Data("ink-v1".utf8), timeout: 30)
        }
    }
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) { Task { @MainActor in fail() } }
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) { Task { @MainActor in fail() } }
    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { stream.close() }
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { progress.cancel() }
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let localURL { try? FileManager.default.removeItem(at: localURL) }
    }
}
