//
//  SettingsController.swift
//  Uber
//
//  Created by Miks Freibergs on 15/07/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import UIKit

private let reuseIdentifier = "LocationCell"

protocol SettingsControllerDelegate: class {
    func updateUser(_ controller: SettingsController)
}

enum LocationType: Int, CaseIterable, CustomStringConvertible {
    case home
    case work
    
    var description: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        }
    }
    
    var subtitle: String {
        switch self {
        case .home: return "Add Home"
        case .work: return "Add Work"
        }
    }
}

class SettingsController: UITableViewController {
    
    // MARK: - Properties
    
    var user: User
    private let locationManager = LocationHandler.shared.locationManager
    weak var delegate: SettingsControllerDelegate?
    var userInfoUpdated = false
    
    private lazy var infoHeader: UserInfoHeader = {
        let frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 100)
        let view = UserInfoHeader(user: user, frame: frame)
        return view
    }()
    
    //MARK: Lifecycle
    
    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureNavigationBar()
    }
    
    // MARK: -Selectors
    
    @objc func handleDismissal() {
        if userInfoUpdated {
            delegate?.updateUser(self)
        }
        self.dismiss(animated: true, completion: nil)
        
    }
    
    // MARK: - Helper Functions
    
    func locationText(forType type: LocationType) -> String {
        switch type {
        case .home:
            return user.homeLocation ?? type.subtitle
        case .work:
            return user.workLocation ?? type.subtitle
        }
    }
    
    func configureTableView() {
        tableView.rowHeight = 60
        tableView.register(LocationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.backgroundColor = .white
        tableView.tableHeaderView = infoHeader
        tableView.tableFooterView = UIView()
    }
    
    func configureNavigationBar() {
        navigationController?.navigationBar.barTintColor = .backgroundColor
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = .black
        navigationItem.title = "Settings"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "baseline_clear_white_36pt_2x").withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(handleDismissal))
    }
}

// MARK: -UITableViewDelegate/DataSource

extension SettingsController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return LocationType.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .black
        
        let title = UILabel()
        title.font = .systemFont(ofSize: 16)
        title.textColor = .white
        title.text = "Favorites"
        view.addSubview(title)
        title.centerY(inView: view)
        title.anchor(left: view.leftAnchor, paddingLeft: 16)
        
        return view
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! LocationCell
        
        guard let type = LocationType(rawValue: indexPath.row) else { return cell }
        cell.titleLabel.text = type.description
        cell.addressLabel.text = locationText(forType: type)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let type = LocationType(rawValue: indexPath.row) else { return }
        guard let location = locationManager?.location else { return }
        let controller = AddLocationController(type: type, location: location)
        controller.delegate = self
        let nav = UINavigationController(rootViewController: controller)
        present(nav, animated: true)
    }
}

extension SettingsController: AddLocationControllerDelegate {
    func updateLocation(location: String, type: LocationType) {
        PassengerService.shared.saveLocation(locationString: location, type: type) { _ in
            self.dismiss(animated: true, completion: nil)
            self.userInfoUpdated = true
            switch type {
            case .home:
                self.user.homeLocation = location
            case .work:
                self.user.workLocation = location
            }
        }
    }
}
