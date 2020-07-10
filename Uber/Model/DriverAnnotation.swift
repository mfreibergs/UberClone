//
//  DriverAnnotation.swift
//  Uber
//
//  Created by Miks Freibergs on 26/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import MapKit

class DriverAnnotation: NSObject, MKAnnotation {
    var uid: String
    dynamic var coordinate: CLLocationCoordinate2D
    
    init(uid: String, coordinate: CLLocationCoordinate2D) {
        self.uid = uid
        self.coordinate = coordinate
    }
    
    func updateAnnotationPosition(withCoordinate coordinate: CLLocationCoordinate2D) {
        UIView.animate(withDuration: 0.2) {
            self.coordinate = coordinate
        }
    }
}
