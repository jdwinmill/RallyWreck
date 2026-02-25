import Foundation
import MultipeerConnectivity

@Observable
final class MultipeerService {
    private static let serviceType = "rallywreck"
    private static let maxPlayers = 5

    private var session: MCSession!
    private var peerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var coordinator: SessionCoordinator!

    // Maps MCPeerID to player UUID string
    private(set) var peerToPlayerID: [MCPeerID: String] = [:]
    private(set) var playerIDToPeer: [String: MCPeerID] = [:]

    var isHosting: Bool = false
    var connectedPeerCount: Int = 0

    // Callbacks
    var onMessageReceived: ((GameMessage, MCPeerID) -> Void)?
    var onPeerConnected: ((MCPeerID) -> Void)?
    var onPeerDisconnected: ((MCPeerID) -> Void)?

    func start(displayName: String, asHost: Bool) {
        peerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        isHosting = asHost

        coordinator = SessionCoordinator(
            session: session,
            onStateChange: { [weak self] peer, state in
                let service = self
                Task { @MainActor in
                    service?.handleStateChange(peer: peer, state: state)
                }
            },
            onDataReceived: { [weak self] data, peer in
                let service = self
                Task { @MainActor in
                    service?.handleDataReceived(data: data, from: peer)
                }
            },
            onInvitation: { [weak self] _, _, handler in
                let service = self
                Task { @MainActor in
                    guard let service else {
                        handler(false, nil)
                        return
                    }
                    let shouldAccept = service.isHosting &&
                        service.session.connectedPeers.count < 4
                    handler(shouldAccept, service.session)
                }
            }
        )

        session.delegate = coordinator

        if asHost {
            advertiser = MCNearbyServiceAdvertiser(
                peer: peerID,
                discoveryInfo: nil,
                serviceType: Self.serviceType
            )
            advertiser?.delegate = coordinator
            advertiser?.startAdvertisingPeer()
        } else {
            browser = MCNearbyServiceBrowser(
                peer: peerID,
                serviceType: Self.serviceType
            )
            browser?.delegate = coordinator
            browser?.startBrowsingForPeers()
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        peerToPlayerID = [:]
        playerIDToPeer = [:]
        connectedPeerCount = 0
    }

    func mapPeer(_ peer: MCPeerID, toPlayerID playerID: String) {
        peerToPlayerID[peer] = playerID
        playerIDToPeer[playerID] = peer
    }

    func send(_ message: GameMessage, to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            print("Send error: \(error)")
        }
    }

    func sendToAll(_ message: GameMessage) {
        send(message, to: session.connectedPeers)
    }

    func sendToPlayer(_ message: GameMessage, playerID: String) {
        guard let peer = playerIDToPeer[playerID] else { return }
        send(message, to: [peer])
    }

    // MARK: - Private

    private func handleStateChange(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            connectedPeerCount = session.connectedPeers.count
            onPeerConnected?(peer)
            // Stop browsing once connected (client side)
            if !isHosting {
                browser?.stopBrowsingForPeers()
            }
        case .notConnected:
            connectedPeerCount = session.connectedPeers.count
            if let playerID = peerToPlayerID[peer] {
                playerIDToPeer.removeValue(forKey: playerID)
            }
            peerToPlayerID.removeValue(forKey: peer)
            onPeerDisconnected?(peer)
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    private func handleDataReceived(data: Data, from peer: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            onMessageReceived?(message, peer)
        } catch {
            print("Decode error: \(error)")
        }
    }

    // MARK: - Delegate Bridge

    /// nonisolated coordinator that bridges MC delegate callbacks to MainActor closures
    private class SessionCoordinator: NSObject,
        MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {

        nonisolated(unsafe) let session: MCSession
        nonisolated let onStateChange: @Sendable (MCPeerID, MCSessionState) -> Void
        nonisolated let onDataReceived: @Sendable (Data, MCPeerID) -> Void
        nonisolated let onInvitation: @Sendable (MCPeerID, Data?, @escaping (Bool, MCSession?) -> Void) -> Void

        nonisolated init(
            session: MCSession,
            onStateChange: @escaping @Sendable (MCPeerID, MCSessionState) -> Void,
            onDataReceived: @escaping @Sendable (Data, MCPeerID) -> Void,
            onInvitation: @escaping @Sendable (MCPeerID, Data?, @escaping (Bool, MCSession?) -> Void) -> Void
        ) {
            self.session = session
            self.onStateChange = onStateChange
            self.onDataReceived = onDataReceived
            self.onInvitation = onInvitation
        }

        // MARK: MCSessionDelegate

        nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
            onStateChange(peerID, state)
        }

        nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
            onDataReceived(data, peerID)
        }

        nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                                 withName streamName: String, fromPeer peerID: MCPeerID) {}

        nonisolated func session(_ session: MCSession,
                                 didStartReceivingResourceWithName resourceName: String,
                                 fromPeer peerID: MCPeerID, with progress: Progress) {}

        nonisolated func session(_ session: MCSession,
                                 didFinishReceivingResourceWithName resourceName: String,
                                 fromPeer peerID: MCPeerID, at localURL: URL?,
                                 withError error: Error?) {}

        // MARK: MCNearbyServiceAdvertiserDelegate

        nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                    didReceiveInvitationFromPeer peerID: MCPeerID,
                                    withContext context: Data?,
                                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            onInvitation(peerID, context, invitationHandler)
        }

        nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                    didNotStartAdvertisingPeer error: Error) {
            print("Advertising error: \(error)")
        }

        // MARK: MCNearbyServiceBrowserDelegate

        nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                                 foundPeer peerID: MCPeerID,
                                 withDiscoveryInfo info: [String: String]?) {
            // Auto-invite the first host found
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }

        nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                                 lostPeer peerID: MCPeerID) {}

        nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                                 didNotStartBrowsingForPeers error: Error) {
            print("Browsing error: \(error)")
        }
    }
}
