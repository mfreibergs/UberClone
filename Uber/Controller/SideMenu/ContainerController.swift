//
//  ContainerController.swift
//  Uber
//
//  Created by Miks Freibergs on 14/07/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import UIKit
import Firebase

class ContainerController: UIViewController {
    
    // MARK: - Properties
    
    private lazy var homeController: HomeController? = HomeController()
    private lazy var menuController: MenuController? = MenuController()
    private var isExpended = false
    private let blackView = UIView()
    
    private var user: User? {
        didSet {
            guard let user = user else { return }
            print("DEBUG: User home location is \(user.homeLocation)")
            homeController?.user = user
            menuController?.user = user
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkIfUserIsLoggedIn()
        NotificationCenter.default.addObserver(self, selector: #selector(self.configure), name: NSNotification.Name(rawValue: "NotificationID"), object: nil)
    }
    
    
    // MARK: - Selectors
    
    @objc func dismissMenu() {
        isExpended = false
        animateMenu(shouldExpand: isExpended)
    }
    
    // MARK: - API
    
    func checkIfUserIsLoggedIn() {
        if Auth.auth().currentUser == nil {
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: LoginController())
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: false)
                self.homeController = nil
                self.menuController = nil
            }
            print("DEBUG: User not logged in")
        } else {
            print("DEBUG: User logged in")
            configure()
        }
    }
    
    func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("DEBUG: Fetching user with uid = \(uid)")
        Service.shared.fetchUserData(uid: uid) { user in
            print("DEBUG: Did it get the new user?")
            self.user = user
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: LoginController())
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
                NotificationCenter.default.addObserver(self, selector: #selector(self.configure), name: NSNotification.Name(rawValue: "NotificationID"), object: nil)
                self.homeController = nil
                self.menuController = nil
                self.view.subviews.forEach({ $0.removeFromSuperview() })
            }
        } catch {
            print("DEBUG: Error signing out")
        }
    }
    
    // MARK: - Helper Functions
    
    @objc func configure() {
        view.backgroundColor = .backgroundColor
        if self.homeController == nil && self.menuController == nil {
            self.homeController = HomeController()
            self.menuController = MenuController()
        }
        configureHomeController()
        fetchUserData()
        configureMenuController()
        NotificationCenter.default.removeObserver(self)
    }
    
    func configureHomeController() {
        guard let homeController = homeController else { return }
        addChild(homeController)
        homeController.didMove(toParent: self)
        view.addSubview(homeController.view)
        homeController.delegate = self
    }
    
    func configureMenuController() {
        guard let menuController = menuController else { return }
        addChild(menuController)
        menuController.didMove(toParent: self)
        view.insertSubview(menuController.view, at: 0)
        print("DEBUG: Added subview")
        menuController.delegate = self
        configureBlackView()
    }
    
    func configureBlackView() {
        blackView.frame = self.view.bounds
        blackView.backgroundColor = .init(white: 0, alpha: 0.5)
        blackView.alpha = 0
        view.addSubview(blackView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissMenu))
        blackView.addGestureRecognizer(tap)
    }
    
    func animateMenu(shouldExpand: Bool) {
        let xOrigin = self.view.frame.width - 80
        
        guard let homeController = homeController else { return }
        if shouldExpand {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
                homeController.view.frame.origin.x = xOrigin
                
            }, completion: { _ in
                self.blackView.alpha = 1
                self.blackView.frame = CGRect(x: xOrigin, y: 0, width: 80, height: self.view.frame.height)
                
            })
        } else {
            self.blackView.alpha = 0
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
                homeController.view.frame.origin.x = 0
            }, completion: nil)
        }
        
    }
    
}

// MARK: - SettingsControllerDelegate

extension ContainerController: SettingsControllerDelegate {
    func updateUser(_ controller: SettingsController) {
        self.user = controller.user
    }
}

// MARK: - HomeControllerDelegate

extension ContainerController: HomeControllerDelegate {
    func handleMenuToggle() {
        isExpended.toggle()
        animateMenu(shouldExpand: isExpended)
    }
}

// MARK: - MenuControllerDelegate

extension ContainerController: MenuControllerDelegate {
    func didSelect(option: MenuOptions) {
        switch option {
        case .yourTrips:
            break
        case .settings:
            guard let user = user else { return }
            let controller = SettingsController(user: user)
            controller.delegate = self
            let nav = UINavigationController(rootViewController: controller)
            
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        case .logout:
            isExpended.toggle()
            animateMenu(shouldExpand: isExpended)
            let alert = UIAlertController(title: nil, message: "Are you sure you want to log out?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { _ in
                self.signOut()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            self.present(alert, animated: true)
        }
    }
}
