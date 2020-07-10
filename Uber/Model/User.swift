//
//  User.swift
//  Uber
//
//  Created by Miks Freibergs on 21/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import CoreLocation

enum AccountType: Int {
    case passenger
    case driver
}

struct User {
    let fullName: String
    let email: String
    var accountType: AccountType!
    var location: CLLocation?
    var uid: String
    
    init(uid: String, dictionary: [String: Any]) {
        self.uid = uid
        self.fullName = dictionary["fullName"] as? String ?? ""
        self.email = dictionary["email"] as? String ?? ""
        
        if let index = dictionary["accountType"] as? Int {
            self.accountType = AccountType(rawValue: index)
        }
    }
}
