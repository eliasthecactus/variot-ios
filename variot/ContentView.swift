//
//  ContentView.swift
//  variot
//
//  Created by Elias Frehner on 04.09.2024.
//

import SwiftUI
import Network

class ServiceBrowser: ObservableObject {
    @Published var devices: [String] = []
    @Published var isLoading: Bool = false
    @Published var discoveryTimedOut: Bool = false
    
    private var browser: NWBrowser?
    private var timeoutTask: Task<Void, Never>? = nil
    
    init() {
        let parameters = NWParameters()
        let serviceType = "_http._tcp."
        
        // Configure the browser for Bonjour service discovery
        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        browser?.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.discoveryTimedOut = false
                }
            case .failed(_):
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.discoveryTimedOut = true
                }
            default:
                break
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                // Only show the service name
                self?.devices = results.map { result in
                    if case let NWEndpoint.service(name, _, _, _) = result.endpoint {
                        return name
                    }
                    return ""
                }.filter { !$0.isEmpty } // Remove empty entries if any
            }
        }
    }
    
    func startDiscovery() {
        isLoading = true
        discoveryTimedOut = false
        devices.removeAll()
        stopDiscovery()  // Ensure previous discovery is stopped
        
        print("Starting discovery...")
        browser?.start(queue: .main)
        
        // Set up a timeout for discovery
        timeoutTask = Task {
            await Task.sleep(20 * 1_000_000_000)  // Increased timeout
            if devices.isEmpty {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.discoveryTimedOut = true
                }
            }
        }
    }
    
    func stopDiscovery() {
        //browser?.cancel()
        timeoutTask?.cancel()
        timeoutTask = nil
        devices.removeAll() // Clear the devices list
        print("Stopped discovery and cleared devices list...")
    }
}

struct ContentView: View {
    @StateObject private var serviceBrowser = ServiceBrowser()
    @State private var selectedDevice: String?

    var body: some View {
        NavigationStack {
            VStack {
                if serviceBrowser.devices.isEmpty {
                    if serviceBrowser.discoveryTimedOut {
                        Text("No devices found. Please try again.")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Text("Searching for devices...")
                            .padding()
                    }
                } else {
                    List {
                        ForEach(serviceBrowser.devices, id: \.self) { device in
                            Button(action: {
                                selectedDevice = device
                            }) {
                                Text(device)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Discover Devices")
            .onAppear {
                serviceBrowser.startDiscovery()
            }
            .onDisappear {
                serviceBrowser.stopDiscovery()
            }
            .navigationDestination(isPresented: Binding<Bool>(
                get: { selectedDevice != nil },
                set: { if !$0 { selectedDevice = nil } }
            )) {
                if let selectedDevice = selectedDevice {
                    HomeView(deviceName: selectedDevice)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
