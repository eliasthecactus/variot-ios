import CoreBluetooth
import SwiftUI


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
            // Bluetooth is ready; start scanning or connecting
            startDiscovery()
        default:
            // Handle other states (not ready for scanning or connecting)
            print("Bluetooth is not ready for scanning or connecting.")
        }
    }

    func startDiscovery() {
        isLoading = true
        discoveryTimedOut = false
        devices.removeAll()
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Set up a timeout for discovery
        timeoutTask = Task {
            await Task.sleep(20 * 1_000_000_000)  // Timeout after 20 seconds
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
        
        // Check if the device is already discovered
        if !discoveredPeripherals.contains(peripheral) {
            let device = Device(name: deviceName, id: deviceID, peripheral: peripheral)
            devices.append(device)
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to "+(peripheral.name ?? " unknown"))
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)  // Discover all services
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)  // Discover all characteristics
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.read) || characteristic.properties.contains(.notify) {
                dataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)  // Subscribe to updates
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value: \(error!.localizedDescription)")
            return
        }
        
        if characteristic == dataCharacteristic {
            if let data = characteristic.value {
                // Handle received data
                let dataString = String(data: data, encoding: .utf8) ?? "Unknown data"
                DispatchQueue.main.async {
                    self.sensorData = dataString
                }
                print("Received data: \(dataString)")
            }
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
    
    // Conform to Hashable
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
                        NavigationLink(value: device) {
                            Text(device.name)
                        }
                        .onTapGesture {
                            serviceBrowser.connect(to: device.peripheral)  // Ensure connection is made
                            selectedDevice = device
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
            .navigationDestination(for: Device.self) { device in
                HomeView(device: device.name)
                    .environmentObject(serviceBrowser)
            }
        }
    }
}

#Preview {
    ConnectView()
}
