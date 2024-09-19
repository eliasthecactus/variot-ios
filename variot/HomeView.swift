import SwiftUI
import MapKit
import CoreLocation
import CoreBluetooth

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation? = nil
    @Published var heading: CLHeading? = nil  // Published heading data

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()  // Start updating the heading (compass)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading  // Update heading when new data is available
    }
}

struct CompassView: View {
    var heading: CLHeading?  // The heading data
    
    var body: some View {
        ZStack {
            // Compass background (a simple circle)
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    // Circle with cardinal direction labels (N, E, S, W)
                    ZStack {
                        Text("N").position(x: 50, y: 10)  // North
                        Text("E").position(x: 90, y: 50)  // East
                        Text("S").position(x: 50, y: 90)  // South
                        Text("W").position(x: 10, y: 50)  // West
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                )
            
            // Compass needle (rotates based on the heading)
            if let heading = heading {
                Image(systemName: "arrow.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .rotationEffect(Angle(degrees: heading.magneticHeading))  // Rotate based on heading
                    .animation(.easeInOut, value: heading.magneticHeading)
            } else {
                Text("N/A")
                    .foregroundColor(.red)
            }
        }
        .shadow(radius: 5)
    }
}

struct HomeView: View {
    @EnvironmentObject var serviceBrowser: BluetoothServiceBrowser
    var device: Device  // Device now includes name
    @State private var buzzerEnabled = true  // State for the muted button

    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),  // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            if let location = locationManager.location {
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        region.center = location.coordinate  // Initial centering on user's location
                    }
            } else {
                Text("Location not available")
                    .padding()
            }
            
            // Gradient overlay for the top 20% of the screen
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(1), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: UIScreen.main.bounds.height * 0.3)  // 20% of screen height
            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.1)
            .allowsHitTesting(false)  // Ensure the gradient doesn't block interaction with the map
            .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.largeTitle)
                            Text(serviceBrowser.altitudeData)
                                .font(.largeTitle)
                        }
                        HStack {
                            Image(systemName: "thermometer.sun.fill")
                                .font(.largeTitle)
                            Text(serviceBrowser.temperatureData+"°C")
                                .font(.largeTitle)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        HStack {
                            // Use phone's compass data instead of Bluetooth angle data
                            if let heading = locationManager.heading {
                                Text(String(format: "%.1f°", heading.magneticHeading))  // Display magnetic heading
                                    .font(.largeTitle)
                            } else {
                                Text("No heading data")
                                    .font(.largeTitle)
                            }
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.largeTitle)

                        }
                    }
                }
                .padding(.horizontal, 10)
                Spacer()
                
                // Recenter button and compass in the bottom-right and bottom-left corners
                HStack {
                    // Add the compass to the bottom-left corner
                    CompassView(heading: locationManager.heading)
                        .padding()
                    
                    Spacer()
                    VStack {
                        Button(action: {
                            buzzerEnabled.toggle()
                            
                            // Send write request to buzzer control characteristic
                            if let buzzerControlCharacteristic = serviceBrowser.buzzerControlCharacteristic {
                                serviceBrowser.mute(peripheral: device.peripheral, buzzerControlCharacteristic: buzzerControlCharacteristic, value: buzzerEnabled)
                            } else {
                                // Handle the case where buzzerControlCharacteristic is nil
                                print("Buzzer control characteristic is nil")
                            }
                            }
                        ) {
                            Image(systemName: buzzerEnabled ? "speaker.wave.2" : "speaker.slash")
                                .font(.title)
                                .padding()
                                .shadow(radius: 10)
                                .background(Circle().fill(Color.white))
                        }
                        Button(action: {
                            if let location = locationManager.location {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    region.center = location.coordinate
                                }
                            }
                        }) {
                            Image(systemName: "location.circle")
                                .font(.title)
                                .shadow(radius: 10)
                                .padding()
                                .background(Circle().fill(Color.white))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
