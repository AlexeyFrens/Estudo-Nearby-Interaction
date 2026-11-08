//
//  NearbyManager.swift
//  NearbyTest
//
//  Created by João Cláudio dos Santos Souza on 02/11/26.
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity

enum ProximityState {
    case waitingForMeasurement
    case nearby
    case farAway
}

enum DeviceSupportState {
    case waitingForVerification
    case supported
    case notSupported
}

@Observable
class NearbyManager: NSObject, NISessionDelegate {
    var sessionsByPeer: [MCPeerID: NISession] = [:]
    var peerBySession: [ObjectIdentifier: MCPeerID] = [:]
    var pendingTokensByPeer: [MCPeerID: NIDiscoveryToken] = [:]
    var proximityByPeer: [MCPeerID: ProximityState] = [:]
    
    var currentDeviceSupportState: DeviceSupportState = .waitingForVerification
    let connection = PeerConnection(displayName: "Jogador")
    
    override init() {
        super.init()
        
        connection.onPeerConnected = { [weak self] peerID in
            guard let self else { return }
            self.prepareSession(for: peerID)
        }
        
        connection.onTokenReceived = { [weak self] peerID, token in
            guard let self else { return }
            self.didReceivePeerToken(token, from: peerID)
        }
        
        connection.onPeerDisconnected = { [weak self] peerID in
            self?.removeSession(for: peerID)
        }
    }
    
    func checkDeviseSupport() {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            print("Dispositivo não suportado")
            currentDeviceSupportState = .notSupported
            return
        }
        
        currentDeviceSupportState = .supported
    }
    
    func prepareSession(for peerID: MCPeerID) {
        guard sessionsByPeer[peerID] == nil else { return }
        
        let session = NISession()
        session.delegate = self
        
        sessionsByPeer[peerID] = session
        peerBySession[ObjectIdentifier(session)] = peerID
        proximityByPeer[peerID] = .waitingForMeasurement
        
        guard let token = session.discoveryToken else { return }
        connection.trySendToken(token: token, to: peerID)
        
        if let pendingToken = pendingTokensByPeer[peerID] {
            pendingTokensByPeer[peerID] = nil
            didReceivePeerToken(pendingToken, from: peerID)
        }
    }
    
    func didReceivePeerToken(_ token: NIDiscoveryToken, from peerID: MCPeerID) {
        guard let session = sessionsByPeer[peerID] else {
            pendingTokensByPeer[peerID] = token
            return
        }
        
        let config = NINearbyPeerConfiguration(peerToken: token)
        session.run(config)
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        guard let peerID = peerBySession[ObjectIdentifier(session)] else { return }
    
        if let distance = object.distance {
            print("Distância: \(distance) m")
        } else {
            print("Distância Indisponível")
        }
        
        if let direction = object.direction {
            print("Direção: \(direction)")
        } else {
            print("Direção Indisponível")
        }
        
        let previousState: ProximityState
        
        if let savedState = proximityByPeer[peerID] {
            previousState = savedState
        } else {
            previousState = .waitingForMeasurement
        }
        
        let nextState = proximityState(for: object.distance, currentState: previousState)
        proximityByPeer[peerID] = nextState
    }
    
    func removeSession(for peerID: MCPeerID) {
        pendingTokensByPeer[peerID] = nil
        proximityByPeer[peerID] = nil
        
        guard let session = sessionsByPeer[peerID] else { return }
        
        peerBySession[ObjectIdentifier(session)] = nil
        sessionsByPeer[peerID] = nil
        session.invalidate()
    }
    
    func proximityState(for distance: Float?, currentState: ProximityState) -> ProximityState {
        guard let distance else { return .waitingForMeasurement }
        
        switch currentState {
        case .waitingForMeasurement:
            if distance < 1 {
                return .nearby
            } else {
                return .farAway
            }
        case .nearby:
            if distance >= 1.2 {
                return .farAway
            } else {
                return .nearby
            }
        case .farAway:
            if distance < 0.8 {
                return .nearby
            } else {
                return .farAway
            }
        }
    }
}
