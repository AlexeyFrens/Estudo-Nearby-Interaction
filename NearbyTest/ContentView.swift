//
//  ContentView.swift
//  NearbyTest
//
//  Created by João Cláudio dos Santos Souza on 02/11/26.
//

import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    
    @State private var manager = NearbyManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            switch manager.currentDeviceSupportState {
            case .waitingForVerification:
                Text("Aguardando verificação")
            case .notSupported:
                Text("Dispositivo não suportado")
            case .supported:
                if manager.proximityByPeer.isEmpty {
                    Text("Aguardando jogadores")
                } else {
                    ForEach(Array(manager.proximityByPeer.keys), id: \.self) { peerID in
                        if let state = manager.proximityByPeer[peerID] {
                            switch state {
                            case .farAway: Text("\(peerID.displayName): Frio")
                            case .nearby: Text("\(peerID.displayName): Quente")
                            case .waitingForMeasurement: Text("\(peerID.displayName): Aguardando medição")
                            }
                        }
                    }
                }
            }
            
            Button("anunciar") {
                manager.connection.startAdvertising()
            }
            
            Button("Procurar Jogador") {
                manager.connection.startBrowsing()
            }
        }
        .padding()
        .onAppear {
            manager.checkDeviseSupport()
        }
    }
}

#Preview {
    ContentView()
}
