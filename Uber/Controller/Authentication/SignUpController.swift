//
//  SignUpController.swift
//  Uber
//
//  Created by Miks Freibergs on 14/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import Geofirestore

class SignUpController: UIViewController {
    
    //MARK: - Properties
    
    private var location = LocationHandler.shared.locationManager.location
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "UBER"
        label.font = UIFont(name: "Avenir-Light", size: 36)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        return label
    }()
    
    private lazy var emailContainerView: UIView = {
        return UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_mail_outline_white_2x"), textField: emailTextField)
    }()
    
    private lazy var fullNameContainerView: UIView = {
        return UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_person_outline_white_2x"), textField: fullNameTextField)
    }()
    
    private lazy var passwordContainerView: UIView = {
        return UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_lock_outline_white_2x"), textField: passwordTextField)
    }()
    
    private lazy var accountTypeContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_account_box_white_2x"), segmentedControl: accountTypeSegmentedControl)
        return view
    }()
    
    private let emailTextField: UITextField = {
        let tf = UITextField().textField(withPlaceholder: "Email", isSecureTextEntry: false)
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        return tf
    }()
    
    private let fullNameTextField: UITextField = {
        let tf = UITextField().textField(withPlaceholder: "Full Name", isSecureTextEntry: false)
        tf.autocapitalizationType = .words
        return tf
    }()
    
    private let passwordTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Password", isSecureTextEntry: true)
    }()
    
    private let accountTypeSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Passenger", "Driver"])
        sc.backgroundColor = .backgroundColor
        sc.tintColor = UIColor(white: 1, alpha: 0.87)
        sc.selectedSegmentIndex = 0
        return sc
    }()
    
    private let signUpButton: UIButton = {
        let button = UIButton().authButton(withTitle: "Sign Up")
        button.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
        return button
        
    }()
    
    private let alreadyHaveAccountButton: UIButton = {
        let button = UIButton().haveAccountButton(firstSring: "Already have an account? ", secondString: "Log In")
        button.addTarget(self, action: #selector(handleShowLogin), for: .touchUpInside)
        return button
    }()
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        
    }
    
    //MARK: - Selectors
    
    @objc func handleSignUp() {
        guard let email = emailTextField.text else { return }
        guard let password = passwordTextField.text else { return }
        guard let fullName = fullNameTextField.text else { return }
        let accountTypeIndex = accountTypeSegmentedControl.selectedSegmentIndex
        
        Auth.auth().createUser(withEmail: email, password: password) { (data, error) in
            if let error = error { print(error.localizedDescription) }
            NotificationCenter.default.post(.init(name: NSNotification.Name(rawValue: "NotificationID")))
            guard let uid = data?.user.uid else { return }
            let values: [String: Any] = ["email": email,
                                         "fullName": fullName,
                                         "accountType": self.accountTypeSegmentedControl.selectedSegmentIndex]
            if accountTypeIndex == 1 {
                guard let location = self.location else { return }
                let geoFirestore = GeoFirestore(collectionRef: REF_DRIVER_LOCATIONS)
                geoFirestore.setLocation(location: location, forDocumentWithID: uid)
            }
            REF_USERS.document(uid).setData(values) { (err) in
                if let err = err { print("DEBUG: Error writing documents: \(err)"); return }
                NotificationCenter.default.post(.init(name: NSNotification.Name(rawValue: "NotificationID")))
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    @objc func handleShowLogin() {
        navigationController?.popViewController(animated: true)
    }
    
    //MARK: - Helper Functions
    
    func configureUI() {
        view.backgroundColor = .backgroundColor
        
        view.addSubview(titleLabel)
        titleLabel.anchor(top: view.safeAreaLayoutGuide.topAnchor)
        titleLabel.centerX(inView: view)
        
        let stack = UIStackView(arrangedSubviews: [emailContainerView,
                                                   fullNameContainerView,
                                                   passwordContainerView,
                                                   accountTypeContainerView,
                                                   signUpButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(24, after: accountTypeContainerView)
        
        view.addSubview(stack)
        stack.anchor(top: titleLabel.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingTop: 40, paddingLeft: 16, paddingRight: 16)
        
        view.addSubview(alreadyHaveAccountButton)
        alreadyHaveAccountButton.centerX(inView: view)
        alreadyHaveAccountButton.anchor(bottom: view.safeAreaLayoutGuide.bottomAnchor, height: 32)
    }
}
