import SwiftUI
import CoreBluetooth

class BluetoothServiceBrowser: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [Device] = []
    @Published var isLoading: Bool = false
    @Published var discoveryTimedOut: Bool = false
    @Published var sensorData: String = ""

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
            await Task.sleep(20 * 1_000_000_000)
            if devices.isEmpty {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.discoveryTimedOut = true
                }
            }
        }
    }

    func stopDiscovery() {
        centralManager.stopScan()
        timeoutTask?.cancel()
        timeoutTask = nil
        devices.removeAll()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        print("Stopped discovery and cleared devices list...")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown Device"
        let deviceID = peripheral.identifier.uuidString
        
        if !discoveredPeripherals.contains(peripheral) {
            let device = Device(name: deviceName, id: deviceID, peripheral: peripheral)
            devices.append(device)
            discoveredPeripherals.append(peripheral)
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
        print("check5")

        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.read) || characteristic.properties.contains(.notify) {
                dataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to notifications for \(characteristic.uuid)")
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

        // Check if the characteristic is the one you're interested in
        if characteristic == dataCharacteristic {
            print("check1")
            if let data = characteristic.value {
                // Convert the data to a string
                let dataString = String(data: data, encoding: .utf8) ?? "Unknown data"
                
                // Update the UI with sensor data
                DispatchQueue.main.async {
                    self.sensorData = dataString
                }

                print("Received data: \(dataString)")
            }
        } else {
            print("check2")
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
    @State private var navigateToHomeView = false

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
                    List(serviceBrowser.devices) { device in
                        Button {
                            serviceBrowser.connect(to: device.peripheral)
                            selectedDevice = device
                            serviceBrowser.isLoading = true
                            
                            // Trigger navigation upon connection
                            navigateToHomeView = true
                        } label: {
                            Text(device.name)
                        }
                    }
                }

                // Loading indicator while connecting
                if serviceBrowser.isLoading {
                    ProgressView("Connecting to device...")
                        .padding()
                }
            }
            .navigationTitle("Discover Devices")
            .onAppear {
                serviceBrowser.startDiscovery()
            }
            .onDisappear {
                serviceBrowser.stopDiscovery()
            }
            .navigationDestination(isPresented: $navigateToHomeView) {
                if let device = selectedDevice {
                    HomeView(device: device.peripheral)
                        .environmentObject(serviceBrowser)
                }
            }
        }
    }
}

#Preview {
    ConnectView()
}
