import SwiftUI
import MapKit
import CoreLocation
import CoreBluetooth

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation? = nil

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
}

struct HomeView: View {
    @EnvironmentObject var serviceBrowser: BluetoothServiceBrowser
    var device: Device  // Device now includes name
    @State private var muted = false  // State for the muted button

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
                            Text(serviceBrowser.temperatureData)
                                .font(.largeTitle)
                        }
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.largeTitle)
                            Text(serviceBrowser.angleData)
                                .font(.largeTitle)
                        }
                    }
                    Spacer()
                }
                Spacer()
                
                // Recenter button in the bottom-right corner
                HStack {
                    Spacer()
                    VStack {
                        Button(action: {
                            muted = !muted;
                            }
                        ) {
                            Image(systemName: muted ? "speaker.slash" : "speaker.wave.2")
                                .font(.title)
                                .padding()
                                .shadow(radius: 10)
                                .background(Circle().fill(Color.white))
                        }
                        //Spacer()
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
                //.background(Color.white)
                //.cornerRadius(100)
                .padding(.horizontal, 20)
            }
        }
    }
}
