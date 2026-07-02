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

    @Published public private(set) var state: State = .idle
    @Published public private(set) var discoveredPeers: [MCPeerID] = []

    private let serviceType = "mdz-logsign"
    private let myPeerId: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingRequest: LogbookSignRequest?
    private let signerUserId: String
    private let signerDisplayName: String
    private let signingKey: P256.Signing.PrivateKey
    private var statusPollTask: Task<Void, Never>?

    public init(userId: Int, displayName: String) {
        self.signerUserId = String(userId)
        self.signerDisplayName = displayName
        self.myPeerId = MCPeerID(displayName: displayName.isEmpty ? "MalfunctionDZ" : displayName)
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.signingKey = MDZDeviceSigningKey.loadOrCreate()
        super.init()
        session.delegate = self
    }

  deinit {
        statusPollTask?.cancel()
    }

    /// Entry owner: advertise a witness request after POST /challenge.
    public func startAdvertising(for request: LogbookSignRequest) {
        stopAll()
        pendingRequest = request
        state = .advertising
        startStatusPolling(entryId: request.entryId)

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

        let br = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
    }

    public func connect(to peer: MCPeerID) {
        state = .connecting
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    /// Signer confirms — POSTs to backend with this device's Bearer token only.
    public func confirmAndSign(_ request: LogbookSignRequest) {
        let coSig = LogbookCoSignature(
            entryId: request.entryId,
            nonce: request.nonce,
            signedAt: Date(),
            deviceSignature: signDeviceAttestation(entryId: request.entryId, nonce: request.nonce),
            signerDisplayName: signerDisplayName
        )
        if let data = try? JSONEncoder().encode(coSig) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        Task {
            await postSignToBackend(coSig)
            state = .completed
            stopAll()
        }
    }

    public func decline() {
        pendingRequest = nil
        state = .idle
        stopAll()
    }

    public func reset() {
        pendingRequest = nil
        state = .idle
        stopAll()
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

    private func postSignToBackend(_ coSig: LogbookCoSignature) async {
        guard let token = KeychainHelper.readToken(), !token.isEmpty,
              let url = URL(string: "\(kServerURL)/api/logbook/\(coSig.entryId)/sign.php") else { return }

        let body: [String: Any] = [
            "entry_id": coSig.entryId,
            "nonce": coSig.nonce,
            "signed_at": ISO8601DateFormatter().string(from: coSig.signedAt),
            "device_signature": coSig.deviceSignature,
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = jsonData

        _ = try? await URLSession.shared.data(for: req)
    }

    private func stopAll() {
        statusPollTask?.cancel()
        statusPollTask = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
    }
}

extension MDZSigningSession: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if let req = self.pendingRequest, let data = try? JSONEncoder().encode(req) {
                    try? session.send(data, toPeers: [peerID], with: .reliable)
                    self.state = .awaitingWitness(req)
                }
            case .connecting:
                self.state = .connecting
            default:
                break
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            if let request = try? JSONDecoder().decode(LogbookSignRequest.self, from: data) {
                self.state = .awaitingConfirmation(request)
                return
            }
            if (try? JSONDecoder().decode(LogbookCoSignature.self, from: data)) != nil {
                // Initiator: peer signed — poll will pick up witnessed status; do NOT POST here.
                self.state = .completed
                self.stopAll()
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MDZSigningSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension MDZSigningSession: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
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
