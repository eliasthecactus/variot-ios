import SwiftUI
import Network
import WebKit
import CoreLocation
import MapKit

struct HomeView: View {
    var deviceName: String

    @State private var altitude: String = "N/A"
    @State private var verticalSpeed: String = "N/A"
    @State private var buzzerEnabled: Bool = true
    @State private var webSocket: URLSessionWebSocketTask?
    @State private var errorMessage: String = ""

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "device.laptopcomputer")
                    .font(.title)
                Text("Device: \(deviceName)")
                    .font(.headline)
                    .padding()
            }

            Spacer()

            HStack {
                Image(systemName: "arrow.up.and.down")
                    .font(.title)
                Text("Altitude: \(altitude) m")
                    .font(.subheadline)
                    .padding()
            }

            HStack {
                Image(systemName: "speedometer")
                    .font(.title)
                Text("Vertical Speed: \(verticalSpeed) m/s")
                    .font(.subheadline)
                    .padding()
            }

            Button(action: {
                toggleBuzzer()
            }) {
                HStack {
                    Image(systemName: buzzerEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.title)
                    Text(buzzerEnabled ? "Disable Sound" : "Enable Sound")
                        .font(.headline)
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(8)
                .padding()
            }

            if !errorMessage.isEmpty {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }

            // Map View
            Map(coordinateRegion: $locationManager.region, showsUserLocation: true)
                .frame(height: 300) // Adjust height as needed

            Spacer()
        }
        .padding()
        .onAppear {
            connectToWebSocket()
        }
        .onDisappear {
            disconnectWebSocket()
        }
        .navigationBarBackButtonHidden(true) // Hide back button
        .navigationTitle("") // Hide the navigation title
    }

    private func connectToWebSocket() {
        let url = URL(string: "ws://192.168.4.1:81/")!
        print("Connecting to WebSocket at \(url)")
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()

        receiveData()
    }

    private func receiveData() {
        webSocket?.receive { result in
            switch result {
            case .success(let message):
                print("Received message: \(message)")
                if case let .string(text) = message, let data = text.data(using: .utf8) {
                    do {
                        let json = try JSONDecoder().decode(VarioData.self, from: data)
                        DispatchQueue.main.async {
                            altitude = String(json.altitude)
                            verticalSpeed = String(json.verticalSpeed)
                            buzzerEnabled = json.buzzerEnabled
                        }
                    } catch {
                        print("Error decoding JSON: \(error)")
                        errorMessage = "Error decoding data"
                    }
                }
                receiveData() // Keep listening for data
            case .failure(let error):
                print("Error receiving data: \(error)")
                errorMessage = "Error receiving data"
            }
        }
    }

    private func toggleBuzzer() {
        let action = buzzerEnabled ? "disable" : "enable"
        let message = "{\"action\": \"\(action)\"}"
        print("Sending message: \(message)")
        webSocket?.send(URLSessionWebSocketTask.Message.string(message)) { error in
            if let error = error {
                print("Error sending message: \(error)")
                errorMessage = "Error sending message"
            }
        }
    }

    private func disconnectWebSocket() {
        print("Disconnecting WebSocket")
        webSocket?.cancel(with: .goingAway, reason: nil)
    }
}

struct VarioData: Codable {
    let altitude: Float
    let verticalSpeed: Float
    let buzzerEnabled: Bool
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(deviceName: "Device Name")
            .previewLayout(.fixed(width: 1024, height: 768)) // Landscape preview
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default location
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.region.center = location.coordinate
        }
    }
}
