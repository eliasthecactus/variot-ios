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
    var device: CBPeripheral

    var body: some View {
        VStack {
            Text("Connected to: \(device.identifier)")
                .padding()

            // Show sensor data received from the Arduino
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
                print("Attempting to connect to: \(device.identifier)")
                serviceBrowser.connect(to: peripheral)
            } else {
                print("No connected peripheral found.")
            }
        }
    }
}


