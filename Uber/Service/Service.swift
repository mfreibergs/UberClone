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

struct Service {
    
    static let shared = Service()
    
    func fetchUserData(uid: String, completion: @escaping(User) -> Void) {
        let docRef = REF_USERS.document(uid)
        docRef.getDocument { (document, error) in
            guard let documentData = document?.data() else { return print("DEBUG: Service document doesn't exist..") }
            completion(User(uid: uid, dictionary: documentData))
        }
    }
    
    func fetchDrivers(location: CLLocation, completion: @escaping(User) -> Void) {
        let geoFire = GeoFirestore(collectionRef: REF_DRIVER_LOCATIONS)
        
        REF_DRIVER_LOCATIONS.addSnapshotListener { (snap, err) in
            geoFire.query(withCenter: location, radius: 50).observe(.documentEntered) { (uid, location) in
                guard let uid = uid else { return }
                self.fetchUserData(uid: uid) { (user) in
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
        
        let values = ["pickupCoordinates": pickupArray, "destinationCoordinates": destinationArray,
        "state": TripState.requested.rawValue] as [String: Any]
        
        REF_TRIPS.document(uid).setData(values, completion: completion)
    }
    
    func observeTrips() {
        REF_TRIPS.addSnapshotListener { (snapshot, error) in
            for document in snapshot!.documents {
                print("DEBUG: \(document.data())")
            }
        }
    }
}
