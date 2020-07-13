//
//  HomeController.swift
//  Uber
//
//  Created by Miks Freibergs on 18/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import UIKit
import Firebase
import MapKit

private let reuseIdentifier = "LocationCell"
private let annotationIdentifier = "DriverAnnotation"

private enum ActionButtonConfiguration {
    case showMenu
    case dismissActionView
    
    init() {
        self = .showMenu
    }
}

private enum AnnotationType: String {
    case pickup
    case destination
}

class HomeController: UIViewController {
    
    //MARK: - Properties
    
    private let signOutButton: UIButton = {
        let button = UIButton().authButton(withTitle: "Sign Out")
        button.addTarget(self, action: #selector(signOut), for: .touchUpInside)
        return button
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_menu_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private let mapView = MKMapView()
    private let locationManager = LocationHandler.shared.locationManager
    
    private let inputActivationView = LocationInputActivationView()
    private let rideActionView = RideActionView()
    private let locationInputView = LocationInputView()
    private let tableView = UITableView()
    private var searchResults = [MKPlacemark]()
    
    private var user: User? {
        didSet {
            locationInputView.user = user
            if user?.accountType == .passenger {
                fetchDrivers()
                configureInputActivationView()
                observeCurrentTrip()
            } else {
                observeTrips()
            }
        }
    }
    
    private var trip: Trip? {
        didSet {
            guard let user = user else { return }
            
            if user.accountType == .driver {
                guard let trip = trip else { return }
                 let controller = PickupController(trip: trip)
                controller.delegate = self
                 controller.modalPresentationStyle = .fullScreen
                 self.present(controller, animated: true)
            } else {
                print("DEBUG: Show ride action view for accepted trip")
            }
        }
    }
    
    private final let locationInputViewHeight: CGFloat = 180
    private final let rideActionViewHeight: CGFloat = 300
    private var actionButtonConfig = ActionButtonConfiguration()
    private var route: MKRoute?
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.checkIfUserIsLoggedIn), name: NSNotification.Name(rawValue: "NotificationID"), object: nil)
//        signOut()
        checkIfUserIsLoggedIn()
        enableLocationServices()
    }
    
    override func viewWillAppear(_ animated: Bool) {
//        guard let trip = trip else { return }
//        print("DEBUG: Trip state is \(trip.state)")
    }
    //MARK: - API
    
    func observeCurrentTrip() {
        Service.shared.observeCurrentTrip { trip in
            print("DEBUG: Current trip changed values")
            self.trip = trip
            
            guard let state = trip.state else { return }
            guard let driverUid = trip.driverUid else { return }
            
            switch state {
            case .requested:
                break
            case .accepted:
                self.shouldPresentLoadingView(false)
                self.removeAnnotationsAndOverlays()
                self.zoomForActiveTrip(withDriverUid: driverUid)
                
                Service.shared.fetchUserData(uid: driverUid) { driver in
                    self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: driver)
                }
            case .driverArrived:
                self.rideActionView.config = .driverArrived
            case .inProgress:
                self.rideActionView.config = .tripInProgress
            case .arrivedAtDestination:
                self.rideActionView.config = .endTrip
            case .completed:
                self.animateRideActionView(shouldShow: false)
                self.mapView.zoomToFit(annotations: self.mapView.annotations)
                self.configureActionButton(config: .showMenu)
                self.presentAlertController(withTitle: "Trip Completed", withMessage: "We hope you enjoyed your trip")
                UIView.animate(withDuration: 0.3) {
                    self.inputActivationView.alpha = 1
                }
            }
        }
    }
    
    func startTrip() {
        guard let trip = self.trip else { return }
        Service.shared.updateTripState(trip: trip, state: .inProgress) { error in
            self.rideActionView.config = .tripInProgress
            self.removeAnnotationsAndOverlays()
            self.mapView.addAnnotationAndSelect(forCoordinate: trip.destinationCoordinates)
            
            let placemark = MKPlacemark(coordinate: trip.destinationCoordinates)
            let mapItem = MKMapItem(placemark: placemark)
            
            self.setCustomRegion(withType: .destination, coordinates: trip.destinationCoordinates)
            self.generatePolyline(toDestination: mapItem)
        }
    }
    
    func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Service.shared.fetchUserData(uid: uid) { user in
            self.user = user
        }
    }
    
    func fetchDrivers() {
        guard let location = locationManager?.location else { return }
        Service.shared.fetchDrivers(location: location) { driver in
            guard let coordinate = driver.location?.coordinate else { return }
            
            var driverIsVisible: Bool {
                return self.mapView.annotations.contains { annotation -> Bool in
                    guard let driverAnno = annotation as? DriverAnnotation else { return false }
                    if driverAnno.uid == driver.uid {
                        driverAnno.updateAnnotationPosition(withCoordinate: coordinate)
                        if let uid = self.trip?.driverUid { self.zoomForActiveTrip(withDriverUid: uid) }
                        return true
                    }
                    return false
                }
            }
            if !driverIsVisible {
                let annotation = DriverAnnotation(uid: driver.uid, coordinate: coordinate)
                self.mapView.addAnnotation(annotation)
              }
        }
    }
    
    func observeTrips() {
        Service.shared.observeTrips { trip in
            print("DEBUG: got a new trip")
            self.trip = trip
        }
    }
    
    @objc func checkIfUserIsLoggedIn() {
        if Auth.auth().currentUser == nil {
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: LoginController())
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: false)
            }
            print("DEBUG: User not logged in")
        } else {
            print("DEBUG: User logged in")
            configureUI()
            fetchUserData()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // MARK: - Selectors
    
    @objc func actionButtonPressed() {
        switch actionButtonConfig {
        case .showMenu:
            print("DEBUG: Show menu")
        case .dismissActionView:
            removeAnnotationsAndOverlays()
            mapView.showAnnotations(mapView.annotations, animated: true)
            UIView.animate(withDuration: 0.3) {
                self.inputActivationView.alpha = 1
                self.configureActionButton(config: .showMenu)
                self.animateRideActionView(shouldShow: false)
            }
        }
    }
    
    @objc func signOut() {
        do {
            try Auth.auth().signOut()
            let nav = UINavigationController(rootViewController: LoginController())
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        } catch {
            print("DEBUG: Error signing out")
        }
    }
    
    //MARK: - Helper Functions
    
    fileprivate func configureActionButton(config: ActionButtonConfiguration) {
        switch config {
        case .showMenu:
            actionButton.setImage(#imageLiteral(resourceName: "baseline_menu_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
            actionButtonConfig = .showMenu
        case .dismissActionView:
            actionButton.setImage(#imageLiteral(resourceName: "baseline_arrow_back_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
            actionButtonConfig = .dismissActionView
        }
    }
    
    func configureUI() {
        configureMapView()
        configureRideActionView()
        configureActionButton()
        configureTableView()
    }
    
    func configureMapView() {
        view.addSubview(mapView)
        mapView.frame = view.frame
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
    }
    
    func configureActionButton() {
        view.addSubview(actionButton)
        actionButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, left: view.leftAnchor, paddingTop: 12, paddingLeft: 12, height: 50, width: 50)
    }
    
    func configureInputActivationView() {
        guard let user = user else { return }
        guard user.accountType == .passenger else { return }
        
        view.addSubview(inputActivationView)
        inputActivationView.anchor(top: actionButton.topAnchor, left: actionButton.rightAnchor, right: view.rightAnchor, paddingLeft: 16, paddingRight: 16, height: 50)
        inputActivationView.alpha = 0
        inputActivationView.delegate = self
        
        UIView.animate(withDuration: 2) {
            self.inputActivationView.alpha = 1
        }
    }
    
    func configureLocationInputView() {
        locationInputView.delegate = self
        view.addSubview(locationInputView)
        locationInputView.anchor(top: view.topAnchor, left: view.leftAnchor, right: view.rightAnchor, height: locationInputViewHeight)
        locationInputView.alpha = 0
        
        UIView.animate(withDuration: 0.5, animations: {
            self.locationInputView.alpha = 1
            self.tableView.frame.origin.y = self.locationInputViewHeight
        })
    }
    
    func configureRideActionView() {
        view.addSubview(rideActionView)
        rideActionView.delegate = self
        rideActionView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: rideActionViewHeight)
    }
    
    func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(LocationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = 60
        tableView.tableFooterView = UIView()
        
        tableView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: view.frame.height - locationInputViewHeight)
        view.addSubview(tableView)
    }
    
    func dismissLocationView(completion: ((Bool) -> Void)?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.tableView.frame.origin.y = self.view.frame.height
            self.locationInputView.alpha = 0
            self.locationInputView.removeFromSuperview()
        }, completion: completion)
    }
    
    func animateRideActionView(shouldShow: Bool, destination: MKPlacemark? = nil, config: RideActionViewConfiguration? = nil, user: User? = nil) {
        
        let yOrigin = shouldShow ? self.view.frame.height - self.rideActionViewHeight : self.view.frame.height
        
        UIView.animate(withDuration: 0.3) {
            self.rideActionView.frame.origin.y = yOrigin
        }
        if shouldShow {
            guard let config = config else { return }
            
            if let destination = destination {
                self.rideActionView.destination = destination
            }
            
            if let user = user {
                rideActionView.user = user
            }
            rideActionView.config = config
        }
    }
}

// MARK: - Map Helper Functions

private extension HomeController {
    func searchBy(naturalLanguageQuery: String, completion: @escaping([MKPlacemark]) -> Void) {
        var results = [MKPlacemark]()
        
        let request = MKLocalSearch.Request()
        request.region = mapView.region
        request.naturalLanguageQuery = naturalLanguageQuery
        
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else { return }
            
            response.mapItems.forEach { (item) in
                results.append(item.placemark)
            }
            completion(results)
        }
    }
    
    func generatePolyline(toDestination destination: MKMapItem) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile
        
        let directionRequest = MKDirections(request: request)
        directionRequest.calculate { (response, error) in
            guard let response = response else { return }
            self.route = response.routes[0]
            guard let polyline = self.route?.polyline else { return }
            self.mapView.addOverlay(polyline)
        }
    }
    
    func removeAnnotationsAndOverlays() {
        mapView.annotations.forEach { annotation in
            if let anno = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(anno)
            }
        }
        if mapView.overlays.count > 0 {
            mapView.removeOverlay(mapView.overlays[0])
        }
    }
    
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager?.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(region, animated: true)
    }
    
    func setCustomRegion(withType type: AnnotationType, coordinates: CLLocationCoordinate2D) {
        let region = CLCircularRegion(center: coordinates, radius: 25, identifier: type.rawValue)
        locationManager?.startMonitoring(for: region)
    }
    
    func zoomForActiveTrip(withDriverUid uid: String) {
        var annotations = [MKAnnotation]()
    
        self.mapView.annotations.forEach { annotation in
            if let anno = annotation as? DriverAnnotation {
                if anno.uid == uid {
                    annotations.append(anno)
                }
            }
            
            if let userAnno = annotation as? MKUserLocation {
                annotations.append(userAnno)
            }
        }
        self.mapView.zoomToFit(annotations: annotations)
    }
}

// MARK: - MKMapViewDelegate

extension HomeController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let user = self.user else { return }
        guard user.accountType == .driver else { return }
        guard let location = userLocation.location else { return }
        Service.shared.updateDriverLocation(location: location)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            view.image = #imageLiteral(resourceName: "hiclipart.com")
            view.anchor(height: 50, width: 50)
            return view
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let route = self.route {
            let polyline = route.polyline
            let lineRendered = MKPolylineRenderer(overlay: polyline)
            lineRendered.strokeColor = .mainBlueTint
            lineRendered.lineWidth = 4
            return lineRendered
        }
        return MKOverlayRenderer()
    }
}

//MARK: - CLLocationManagerDelegate

extension HomeController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard let trip = self.trip else { return }
        
        if region.identifier == AnnotationType.pickup.rawValue {
            Service.shared.updateTripState(trip: trip, state: .driverArrived) { error in
                self.rideActionView.config = .pickupPassenger
            }
        }
        
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did start monitoring destination region \(region)")
            Service.shared.updateTripState(trip: trip, state: .driverArrived) { error in
                self.rideActionView.config = .pickupPassenger
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("DEBUG: Driver did enter passenger region..")
        self.rideActionView.config = .pickupPassenger
        guard let trip = self.trip else { return }
        
        if region.identifier == AnnotationType.pickup.rawValue {
            Service.shared.updateTripState(trip: trip, state: .driverArrived) { error in
                self.rideActionView.config = .pickupPassenger
            }
        }
        
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did start monitoring destination region \(region)")
            Service.shared.updateTripState(trip: trip, state: .arrivedAtDestination) { error in
                self.rideActionView.config = .endTrip
            }
        }
    }
    
    func enableLocationServices() {
        locationManager?.delegate = self
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            print("DEBUG: Not determined..")
            locationManager?.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways:
            print("DEBUG: Auth always..")
            locationManager?.startUpdatingLocation()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            print("DEBUG: Auth when in use..")
            locationManager?.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - LocationInputActivationViewDelegate

extension HomeController: LocationInputActivationViewDelegate {
    
    func presentLocationInputView() {
        inputActivationView.alpha = 0
        configureLocationInputView()
    }
}

// MARK: - LocationInputViewDelegate

extension HomeController: LocationInputViewDelegate {
    func executeSearch(query: String) {
        searchBy(naturalLanguageQuery: query) { (results) in
            self.searchResults = results
            self.tableView.reloadData()
        }
    }
    
    func dismissLocationInputView() {
        dismissLocationView { _ in
            UIView.animate(withDuration: 0.2) {
                self.inputActivationView.alpha = 1
            }
        }
    }
}

// MARK: - UITableViewDelegate/DataSource

extension HomeController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Test"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 2 : searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! LocationCell
        if indexPath.section == 1 {
            cell.placemark = searchResults[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        configureActionButton(config: .dismissActionView)
        
        let selectedPlacemark = searchResults[indexPath.row]
        let destination = MKMapItem(placemark: selectedPlacemark)
        generatePolyline(toDestination: destination)
        
        dismissLocationView { _ in
            self.mapView.addAnnotationAndSelect(forCoordinate: selectedPlacemark.coordinate)
            
            let annotations = self.mapView.annotations.filter({ !$0.isKind(of: DriverAnnotation.self) })
            self.mapView.zoomToFit(annotations: annotations)
            self.animateRideActionView(shouldShow: true, destination: selectedPlacemark, config: .requestRide)
        }
    }
}

// MARK: - RideActionViewDelegate

extension HomeController: RideActionViewDelegate {
    func uploadTrip(_ view: RideActionView) {
        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
        guard let destinationCoordinates = view.destination?.coordinate else { return }
        shouldPresentLoadingView(true, message: "Finding you a ride..")
        Service.shared.uploadTrip(pickupCoordinates, destinationCoordinates) { (err) in
            if err != nil {
                print("DEBUG: Failed to upload trip with error")
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.rideActionView.frame.origin.y = self.view.frame.height
                }
            }
        }
    }
    
    func cancelTrip() {
        Service.shared.cancelTrip { error in
            if error != nil {
                print("DEBUG: Error deleting trip..")
                return
            }
            self.animateRideActionView(shouldShow: false)
            self.removeAnnotationsAndOverlays()
            self.mapView.zoomToFit(annotations: self.mapView.annotations)
            self.inputActivationView.alpha = 1
            self.configureActionButton(config: .showMenu)
        }
    }
    
    func pickupPassenger() {
        startTrip()
    }
    
    func dropOffPassenger() {
        guard let trip = self.trip else { return }
        Service.shared.updateTripState(trip: trip, state: .completed) { error in
            self.removeAnnotationsAndOverlays()
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
        }
    }
}

// MARK: - PickupControllerDelegate

extension HomeController: PickupControllerDelegate {
    func didAcceptTrip(_ trip: Trip) {
        self.trip = trip

        self.mapView.addAnnotationAndSelect(forCoordinate: trip.pickupCoordinates)
        
        setCustomRegion(withType: .pickup, coordinates: trip.pickupCoordinates)
        
        let placemark = MKPlacemark(coordinate: trip.pickupCoordinates)
        let mapItem = MKMapItem(placemark: placemark)
        generatePolyline(toDestination: mapItem)
        
        mapView.zoomToFit(annotations: mapView.annotations)
        
        Service.shared.observeTripCancelled(trip: trip) {
            self.removeAnnotationsAndOverlays()
            self.animateRideActionView(shouldShow: false)
            self.centerMapOnUserLocation()
            self.presentAlertController(withTitle: "Oops!",withMessage: "The passenger has cancelled this trip. Press OK to continue")
        }
        
        self.dismiss(animated: true) {
            Service.shared.fetchUserData(uid: trip.passengerUid) { passenger in
                self.animateRideActionView(shouldShow: true, destination: placemark, config: .tripAccepted, user: passenger)
                Service.shared.updateTripState(trip: trip, state: .accepted, completion: nil)
            }
        }
    }
}
