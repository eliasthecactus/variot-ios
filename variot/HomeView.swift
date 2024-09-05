//
//  HomeView.swift
//  variot
//
//  Created by Elias Frehner on 05.09.2024.
//

import SwiftUI
import CoreBluetooth

struct HomeView: View {
    @EnvironmentObject var serviceBrowser: BluetoothServiceBrowser
    var device: String

    var body: some View {
        VStack {
            Text("Connected to: \(device)")
            if serviceBrowser.sensorData.isEmpty {
                Text("Waiting for sensor data...")
                    .padding()
            } else {
                Text("Received Data: \(serviceBrowser.sensorData)")
                    .padding()
            }
        }
        .onAppear {
            if let peripheral = serviceBrowser.connectedPeripheral {
                print("Attempting to connect to: \(peripheral)")
                serviceBrowser.connect(to: peripheral)
            } else {
                print("No connected peripheral found.")
            }
        }
    }
}


#Preview {
    HomeView(device: "Vario-769789").environmentObject(BluetoothServiceBrowser())
}
