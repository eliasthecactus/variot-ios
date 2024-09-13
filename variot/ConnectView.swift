import SwiftUI
import CoreBluetooth

class BluetoothServiceBrowser: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [Device] = []
    @Published var isLoading: Bool = false
    @Published var discoveryTimedOut: Bool = false
    @Published var isConnected: Bool = false  // Track the connection status
    
    public var buzzerControlCharacteristic: CBCharacteristic?
    private var altitudeCharacteristic: CBCharacteristic?
    private var pressureCharacteristic: CBCharacteristic?
    private var angleCharacteristic: CBCharacteristic?
    
    @Published var altitudeData: String = ""
    @Published var temperatureData: String = ""
    @Published var angleData: String = ""
    
    @Published var test: [Date: String] = [:]


    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [CBPeripheral] = []
    private var timeoutTask: Task<Void, Never>? = nil
    
    var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startDiscovery()
        default:
            print("Bluetooth is not ready for scanning or connecting.")
        }
    }

    func startDiscovery() {
        isLoading = true
        discoveryTimedOut = false
        devices.removeAll()
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        timeoutTask = Task {
            await Task.sleep(20 * 1_000_000_000) // 20 seconds timeout
            if devices.isEmpty {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.discoveryTimedOut = true
                    self.stopDiscovery() // Stop discovery after timeout
                }
            } else {
                // Discovery succeeded, stop scanning
                self.stopDiscovery()
            }
        }
    }

    func stopDiscovery() {
        centralManager.stopScan()
        timeoutTask?.cancel()
        timeoutTask = nil
        print("Stopped discovery.")
    }
    
    func mute(peripheral: CBPeripheral, buzzerControlCharacteristic: CBCharacteristic, value: Bool) {
        peripheral.writeValue(Data([value ? 1 : 0]), for: buzzerControlCharacteristic, type: .withResponse)
        print("Change Buzzer")
    }

    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from " + (peripheral.name ?? "unknown"))
        DispatchQueue.main.async {
            self.isConnected = false  // Set isConnected to false when disconnected
            self.connectedPeripheral = nil  // Clear the connected peripheral
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if the advertisement data contains any service UUIDs
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            for serviceUUID in serviceUUIDs {
                // Check if the service UUID starts with "19B10000"
                if serviceUUID.uuidString.hasPrefix("19B10000") {
                    let deviceName = peripheral.name ?? "Unknown Device"
                    let deviceID = peripheral.identifier.uuidString
                    
                    if !discoveredPeripherals.contains(peripheral) {
                        let device = Device(name: deviceName, id: deviceID, peripheral: peripheral)
                        devices.append(device)
                        discoveredPeripherals.append(peripheral)
                    }
                    break // Stop checking once we find a match
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to " + (peripheral.name ?? "unknown"))
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        // Trigger the update for navigating to HomeView after connection
        DispatchQueue.main.async {
            self.isLoading = false
            self.isConnected = true // Set isConnected to true after successful connection
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        print("check3")
        for service in peripheral.services ?? [] {
            print("check4")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            print("Discovered characteristic: \(characteristic.uuid.uuidString)")

            // Check if the characteristic supports .read or .notify
            if characteristic.properties.contains(.read) || characteristic.properties.contains(.notify) {
                switch characteristic.uuid.uuidString {
                case "19B10001-E8F2-537E-4F6C-D104768A1214":
                    altitudeCharacteristic = characteristic
                case "19B10002-E8F2-537E-4F6C-D104768A1214":
                    pressureCharacteristic = characteristic
                case "19B10003-E8F2-537E-4F6C-D104768A1214":
                    angleCharacteristic = characteristic
                default:
                    break
                }
                // Subscribe to notifications for readable/notifiable characteristics
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to notifications for \(characteristic.uuid)")
            } else if characteristic.properties.contains(.write) {
                switch characteristic.uuid.uuidString {
                case "19B10004-E8F2-537E-4F6C-D104768A1214":
                    buzzerControlCharacteristic = characteristic
                    print("Buzzer control characteristic supports write only")
                default:
                    break
                }
            } else {
                print("Characteristic \(characteristic.uuid) does not support read/notify")
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value: \(error!.localizedDescription)")
            return
        }

        if characteristic == altitudeCharacteristic {
            if let data = characteristic.value {
                let altitudeString = String(data: data, encoding: .utf8) ?? "Unknown data"
                print("Received altitude data: \(altitudeString)")
                self.altitudeData = altitudeString
                self.test[Date()] = altitudeString
                // Update your altitude data
            }
        } else if characteristic == pressureCharacteristic {
            if let data = characteristic.value {
                let temperatureString = String(data: data, encoding: .utf8) ?? "Unknown data"
                print("Received Temperature data: \(temperatureString)")
                self.temperatureData = temperatureString
                // Update your pressure data
            }
        } else if characteristic == angleCharacteristic {
            if let data = characteristic.value {
                let angleString = String(data: data, encoding: .utf8) ?? "Unknown data"
                print("Received angle data: \(angleString)")
                self.angleData = angleString
                // Update your angle data
            }
        } else {
            print("Unknown characteristic updated")
        }
    }
    
    
    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }
}

struct Device: Identifiable, Hashable {
    let name: String
    let id: String
    let peripheral: CBPeripheral
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.id == rhs.id
    }
}


struct ConnectView: View {
    @StateObject private var serviceBrowser = BluetoothServiceBrowser()
    @State private var selectedDevice: Device?
    @State private var isConnecting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack {
            if serviceBrowser.isConnected, let device = selectedDevice {
                HomeView(device: device)
                    .environmentObject(serviceBrowser)
                    .onAppear {
                        // Handle connection loss, move back to ConnectView if disconnected
                        if !serviceBrowser.isConnected {
                            selectedDevice = nil  // Reset selectedDevice on disconnect
                        }
                    }
            } else {
                Text("Connect a device")
                    .font(.largeTitle)
                Spacer()

                if serviceBrowser.devices.isEmpty {
                    if serviceBrowser.discoveryTimedOut {
                        Button(action: {
                            serviceBrowser.startDiscovery()
                        }) {
                            Label("Reload", systemImage: "arrow.clockwise")
                                .labelStyle(.iconOnly)
                        }
                    } else {
                        Text("Scanning for devices...")
                    }
                } else if isConnecting {
                    VStack {
                        Text("Connecting to \(selectedDevice?.name ?? "device")...")
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                } else {
                    List(serviceBrowser.devices) { device in
                        Button {
                            isConnecting = true
                            serviceBrowser.connect(to: device.peripheral)
                            selectedDevice = device
                        } label: {
                            Text(device.name)
                        }
                    }
                }
            }
        }
        .onAppear {
            serviceBrowser.startDiscovery()
        }
        .onDisappear {
            serviceBrowser.stopDiscovery()
            serviceBrowser.connectedPeripheral = nil
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if serviceBrowser.isLoading && !isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Connecting"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onChange(of: serviceBrowser.isLoading) { isLoading in
            if !isLoading {
                if isConnecting {
                    alertMessage = "Connection established successfully."
                    showAlert = true
                    isConnecting = false
                }
            }
        }
        .onChange(of: serviceBrowser.discoveryTimedOut) { timedOut in
            if timedOut {
                alertMessage = "No devices found. Please try again."
                showAlert = true
            }
        }
        .onChange(of: serviceBrowser.isConnected) { connected in
            if !connected {
                selectedDevice = nil  // Reset the view when the connection is lost
                isConnecting = false
            }
        }
    }
}


    #Preview {
        ConnectView()
    }
