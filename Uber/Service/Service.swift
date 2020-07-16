//
//  Service.swift
//  Uber
//
//  Created by Miks Freibergs on 21/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import Firebase
import CoreLocation
import Geofirestore

// Firestore.firestore().collection("users").document(firUser.uid).setData([

let DB_REF = Firestore.firestore()
let REF_USERS = DB_REF.collection("users")
let REF_DRIVER_LOCATIONS = DB_REF.collection("driver-locations")
let REF_TRIPS = DB_REF.collection("trips")

// MARK: - Diver Service

struct DriverService {
    static let shared = DriverService()
    
    func observeTrips(completion: @escaping(Trip) -> Void) {
        REF_TRIPS.addSnapshotListener { (snapshot, error) in
            snapshot?.documentChanges.forEach({ (change) in
                if change.type == .added {
                    let document = change.document
                    let uid = document.documentID
                    let trip = Trip(passengerUid: uid, dictionary: document.data())
                    completion(trip)
                }
            })
        }
    }
    
    func observeTripCancelled(trip: Trip, completion: @escaping(Bool) -> Void) {
        REF_TRIPS.addSnapshotListener { (snapshot, error) in
            snapshot?.documentChanges.forEach({ (change) in
                if change.type == .removed {
                    guard let uid = Auth.auth().currentUser?.uid else { return }
                    guard let driverUid = change.document.data()["driverUid"] as? String else { return }
                    guard let tripState = change.document.data()["state"] as? Int else { return }
                    if driverUid == uid {
                        if TripState.completed.rawValue == tripState {
                            completion(false)
                        } else {
                            completion(true)
                        }
                    }
                }
            })
        }
    }
    
    func acceptTrip(trip: Trip, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let values = ["driverUid": uid, "state": TripState.accepted.rawValue] as [String: Any]
        REF_TRIPS.document(trip.passengerUid).updateData(values, completion: completion)
    }
    
    func updateTripState(trip: Trip, state: TripState, completion: ((Error?) -> Void)?) {
        REF_TRIPS.document(trip.passengerUid).updateData(["state": state.rawValue], completion: completion)
    }
    
    func updateDriverLocation(location: CLLocation) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let geoFirestore = GeoFirestore(collectionRef: REF_DRIVER_LOCATIONS)
        geoFirestore.setLocation(location: location, forDocumentWithID: uid)
    }
}

// MARK: - Passenger Service

struct PassengerService {
    static let shared = PassengerService()
    
    func fetchDrivers(location: CLLocation, completion: @escaping(User) -> Void) {
        let geoFire = GeoFirestore(collectionRef: REF_DRIVER_LOCATIONS)
        
        REF_DRIVER_LOCATIONS.addSnapshotListener { (snap, err) in
            // FIXME: - Add let _ = geofire.query(... to get rid of the error, but don't have time to test if it will affect the app right now
            geoFire.query(withCenter: location, radius: 50).observe(.documentEntered) { (uid, location) in
                guard let uid = uid else { return }
                Service.shared.fetchUserData(uid: uid) { (user) in
                    var driver = user
                    driver.location = location
                    completion(driver)
                }
            }
        }
    }
    
    func uploadTrip(_ pickupCoordinates: CLLocationCoordinate2D, _ destinationCoordinates: CLLocationCoordinate2D, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let pickupArray = [pickupCoordinates.latitude, pickupCoordinates.longitude]
        let destinationArray = [destinationCoordinates.latitude, destinationCoordinates.longitude]
        
        let values = ["pickupCoordinates": pickupArray,
                      "destinationCoordinates": destinationArray,
                      "state": TripState.requested.rawValue] as [String: Any]
        
        REF_TRIPS.document(uid).setData(values, completion: completion)
    }
    
    func observeCurrentTrip(completion: @escaping(Trip) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_TRIPS.document(uid).addSnapshotListener { (snapshot, error) in
            guard let uid = snapshot?.documentID else { return }
            guard let data = snapshot?.data() else { return }
            let trip = Trip(passengerUid: uid, dictionary: data)
            completion(trip)
        }
    }
    
    func saveLocation(locationString: String, type: LocationType, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let key: String = type == .home ? "homeLocation" : "workLocation"
        REF_USERS.document(uid).updateData([key: locationString], completion: completion)
    }
    
}

// MARK: - Shared Service

struct Service {
    
    static let shared = Service()
    
    func fetchUserData(uid: String, completion: @escaping(User) -> Void) {
        let docRef = REF_USERS.document(uid)
        docRef.getDocument { (document, error) in
            guard let documentData = document?.data() else { return print("DEBUG: Service document doesn't exist..") }
            completion(User(uid: uid, dictionary: documentData))
        }
    }
    
    func deleteTrip(completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_TRIPS.document(uid).delete(completion: completion)
    }
}
