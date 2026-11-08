//
//  PeerConnection.swift
//  NearbyTest
//
//  Created by João Cláudio dos Santos Souza on 03/11/26.
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity

class PeerConnection: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    
    let peerID: MCPeerID
    let communicationSession: MCSession
    var onPeerConnected: ((MCPeerID) -> Void)?
    var onPeerDisconnected: ((MCPeerID) -> Void)?
    var onTokenReceived: ((MCPeerID, NIDiscoveryToken) -> Void)?
    let advertiser: MCNearbyServiceAdvertiser
    let browser: MCNearbyServiceBrowser
    
    init(displayName: String) {
        let peer = MCPeerID(displayName: displayName)
        peerID = peer
        communicationSession = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: nil,
            serviceType: "quente-frio")
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "quente-frio")
        super.init()
        communicationSession.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, communicationSession)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(
            peerID,
            to: self.communicationSession,
            withContext: nil,
            timeout: 30
        )
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
    
    func startAdvertising() {
        advertiser.startAdvertisingPeer()
    }
    
    func startBrowsing() {
        browser.startBrowsingForPeers()
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            switch state {
            case .notConnected:
                self.onPeerDisconnected?(peerID)
            case .connecting:
                break
            case .connected:
                self.onPeerConnected?(peerID)
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self,
                from: data
            ) else {
                print("Dados recebidos não contém um token")
                return
            }
            
            print("Token recebido de \(peerID.displayName)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.onTokenReceived?(peerID, token)
            }
            
            print("Token reconstruído: \(token)")
        } catch {
            print(error)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {
        
    }
    
    func trySendToken(token: NIDiscoveryToken, to peerID: MCPeerID) {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            
            try communicationSession.send(data, toPeers: [peerID], with: .reliable)
        } catch {
            print(error.localizedDescription)
        }
    }
}
