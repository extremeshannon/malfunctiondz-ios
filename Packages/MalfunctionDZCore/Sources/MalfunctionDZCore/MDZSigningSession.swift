import Foundation
import MultipeerConnectivity
import CryptoKit

public struct LogbookSignRequest: Codable, Sendable, Equatable {
    public let entryId: Int
    public let nonce: String
    public let requestedAt: Date
    public let summary: String

    public init(entryId: Int, nonce: String, requestedAt: Date = Date(), summary: String) {
        self.entryId = entryId
        self.nonce = nonce
        self.requestedAt = requestedAt
        self.summary = summary
    }
}

public struct LogbookCoSignature: Codable, Sendable, Equatable {
    public let entryId: Int
    public let nonce: String
    public let signedAt: Date
    public let deviceSignature: String
    public let signerDisplayName: String

    public init(entryId: Int, nonce: String, signedAt: Date, deviceSignature: String, signerDisplayName: String) {
        self.entryId = entryId
        self.nonce = nonce
        self.signedAt = signedAt
        self.deviceSignature = deviceSignature
        self.signerDisplayName = signerDisplayName
    }
}

@MainActor
public final class MDZSigningSession: NSObject, ObservableObject {
    public enum State: Equatable {
        case idle
        case advertising
        case browsing
        case connecting
        case awaitingConfirmation(LogbookSignRequest)
        case awaitingWitness(LogbookSignRequest)
        case completed
        case failed(String)
    }

    public struct DiscoveredPeer: Identifiable, Equatable {
        public let id: String
        public let peer: MCPeerID

        public init(peer: MCPeerID) {
            self.peer = peer
            self.id = peer.displayName
        }
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var discoveredPeers: [DiscoveredPeer] = []

    private let serviceType = "mdz-logsign"
    private let myPeerId: MCPeerID
    /// Fresh session per advertise / browse / invite — reusing a dead MCSession breaks reconnects.
    private var session: MCSession!
    /// Read synchronously from advertiser delegate (must not hop through MainActor).
    private nonisolated(unsafe) var invitationSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingRequest: LogbookSignRequest?
    private let signerUserId: String
    private let signerDisplayName: String
    private let signingKey: P256.Signing.PrivateKey
    private var statusPollTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var connectingToPeer: MCPeerID?
    private var hasConnectedToPeer = false

    public init(userId: Int, displayName: String) {
        self.signerUserId = String(userId)
        self.signerDisplayName = displayName
        let label = displayName.isEmpty ? "MalfunctionDZ" : displayName
        // Unique per account so two phones with the same name don't confuse Bonjour.
        self.myPeerId = MCPeerID(displayName: "\(label) #\(userId)")
        self.signingKey = MDZDeviceSigningKey.loadOrCreate()
        super.init()
        self.session = makeSession()
    }

    deinit {
        statusPollTask?.cancel()
        connectionTimeoutTask?.cancel()
        session?.disconnect()
    }

    /// Entry owner: advertise a witness request after POST /challenge.
    public func startAdvertising(for request: LogbookSignRequest) {
        stopAll()
        pendingRequest = request
        state = .advertising
        startStatusPolling(entryId: request.entryId)

        session = makeSession()
        invitationSession = session

        let adv = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: ["entryId": String(request.entryId)],
            serviceType: serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    /// Pilot / skydiver witness: browse for nearby signing requests.
    public func startBrowsing() {
        stopAll()
        state = .browsing
        discoveredPeers.removeAll()

        session = makeSession()
        invitationSession = nil

        let br = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
    }

    public func connect(to peer: MCPeerID) {
        guard browser != nil else { return }
        connectionTimeoutTask?.cancel()
        hasConnectedToPeer = false
        connectingToPeer = peer
        state = .connecting

        session.disconnect()
        session = makeSession()

        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 60)

        connectionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 65_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if case .connecting = self.state {
                self.session.disconnect()
                self.connectingToPeer = nil
                self.state = .failed(
                    "Connection timed out. Keep both phones on this screen, tap Connect again, or scan the QR code."
                )
            }
        }
    }

    /// Signer confirms — POSTs to backend with this device's Bearer token only.
    public func confirmAndSign(_ request: LogbookSignRequest, witnessNotes: String = "") {
        let coSig = LogbookCoSignature(
            entryId: request.entryId,
            nonce: request.nonce,
            signedAt: Date(),
            deviceSignature: signDeviceAttestation(entryId: request.entryId, nonce: request.nonce),
            signerDisplayName: signerDisplayName
        )
        if let data = try? Self.jsonEncoder.encode(coSig) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        Task {
            let ok = await postSignToBackend(coSig, witnessNotes: witnessNotes)
            if ok {
                state = .completed
                stopAll()
            } else {
                state = .failed("Could not save signature — check Profile signature and try again.")
            }
        }
    }

    public func decline() {
        pendingRequest = nil
        connectingToPeer = nil
        hasConnectedToPeer = false
        state = .idle
        stopAll()
    }

    public func reset() {
        pendingRequest = nil
        connectingToPeer = nil
        hasConnectedToPeer = false
        state = .idle
        stopAll()
    }

    private func makeSession() -> MCSession {
        let s = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .optional)
        s.delegate = self
        return s
    }

    private func signDeviceAttestation(entryId: Int, nonce: String) -> String {
        let message = "\(entryId)|\(nonce)|\(signerUserId)"
        let digest = SHA256.hash(data: Data(message.utf8))
        let sig = try? signingKey.signature(for: digest)
        return sig?.derRepresentation.base64EncodedString() ?? ""
    }

    private func startStatusPolling(entryId: Int) {
        statusPollTask?.cancel()
        statusPollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if case .completed = self.state { return }
                if await self.pollWitnessed(entryId: entryId) {
                    self.state = .completed
                    self.stopAll()
                    return
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func pollWitnessed(entryId: Int) async -> Bool {
        guard let url = URL(string: "\(kServerURL)/api/logbook/\(entryId)/status.php") else { return false }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["witnessed"] as? Bool == true {
                return true
            }
        } catch {}
        return false
    }

    private func postSignToBackend(_ coSig: LogbookCoSignature, witnessNotes: String) async -> Bool {
        guard let token = KeychainHelper.readToken(), !token.isEmpty,
              let url = URL(string: "\(kServerURL)/api/logbook/\(coSig.entryId)/sign.php") else { return false }

        var body: [String: Any] = [
            "entry_id": coSig.entryId,
            "nonce": coSig.nonce,
            "signed_at": ISO8601DateFormatter().string(from: coSig.signedAt),
            "device_signature": coSig.deviceSignature,
        ]
        let notes = witnessNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            body["witness_notes"] = notes
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = jsonData

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { return false }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["witnessed"] as? Bool == true || json["ok"] as? Bool == true
            }
            return false
        } catch {
            return false
        }
    }

    private func stopAll() {
        statusPollTask?.cancel()
        statusPollTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session?.disconnect()
        invitationSession = nil
    }

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension MDZSigningSession: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectionTimeoutTask?.cancel()
                self.hasConnectedToPeer = true
                self.connectingToPeer = nil
                if let req = self.pendingRequest, let data = try? Self.jsonEncoder.encode(req) {
                    try? session.send(data, toPeers: [peerID], with: .reliable)
                    self.state = .awaitingWitness(req)
                }
            case .connecting:
                self.state = .connecting
            case .notConnected:
                guard !self.hasConnectedToPeer else { return }
                guard case .connecting = self.state else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !self.hasConnectedToPeer, case .connecting = self.state else { return }
                    self.connectionTimeoutTask?.cancel()
                    self.connectingToPeer = nil
                    self.state = .failed(
                        "Could not connect. Allow Local Network for MalfunctionDZ on both phones, stay on this screen, tap Connect again, or scan the QR code."
                    )
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            if let request = try? Self.jsonDecoder.decode(LogbookSignRequest.self, from: data) {
                self.connectionTimeoutTask?.cancel()
                self.hasConnectedToPeer = true
                self.state = .awaitingConfirmation(request)
                return
            }
            if (try? Self.jsonDecoder.decode(LogbookCoSignature.self, from: data)) != nil {
                self.state = .completed
                self.stopAll()
                return
            }
            if self.browser != nil {
                self.state = .failed("Could not read the jump signing request. Try again.")
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MDZSigningSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Must accept immediately — async dispatch often causes invite timeout.
        invitationHandler(true, invitationSession)
    }

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.state = .failed(error.localizedDescription)
        }
    }
}

extension MDZSigningSession: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            let row = DiscoveredPeer(peer: peerID)
            if !self.discoveredPeers.contains(where: { $0.id == row.id }) {
                self.discoveredPeers.append(row)
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0.peer == peerID }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.state = .failed(error.localizedDescription)
        }
    }
}

enum MDZDeviceSigningKey {
    private static let account = "device_signing_key"

    static func loadOrCreate() -> P256.Signing.PrivateKey {
        if let data = KeychainHelper.readGeneric(account: account),
           let key = try? P256.Signing.PrivateKey(derRepresentation: data) {
            return key
        }
        let key = P256.Signing.PrivateKey()
        _ = KeychainHelper.saveGeneric(key.derRepresentation, account: account)
        return key
    }
}
