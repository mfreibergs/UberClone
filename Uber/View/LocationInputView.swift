//
//  LocationInputView.swift
//  Uber
//
//  Created by Miks Freibergs on 20/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import UIKit

protocol LocationInputViewDelegate {
    func dismissLocationInputView()
    func executeSearch(query: String)
}

class LocationInputView: UIView {
    
    // MARK: - Properties
    
    var user: User? {
        didSet { titleLabel.text = user?.fullName }
    }
    
    var delegate: LocationInputViewDelegate?
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_arrow_back_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleBackTapped), for: .touchUpInside)
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .darkGray
        label.font = .systemFont(ofSize: 16)
        return label
    }()
    
    private lazy var startingLocationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Current Location"
        tf.backgroundColor = .init(white: 0.7, alpha: 1)
        tf.font = .systemFont(ofSize: 14)
        tf.isEnabled = false
        
        let paddingView = UIView()
        paddingView.anchor(height: 30, width: 8)
        tf.leftView = paddingView
        tf.leftViewMode = .always
        return tf
    }()
    
    private lazy var destinationLocationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter a destination.."
        tf.backgroundColor = .init(white: 0.5, alpha: 1)
        tf.returnKeyType = .search
        tf.font = .systemFont(ofSize: 14)
        tf.delegate = self
        
        let paddingView = UIView()
        paddingView.anchor(height: 30, width: 8)
        tf.leftView = paddingView
        tf.leftViewMode = .always
        return tf
    }()
    
    private let startIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .init(white: 0.7, alpha: 1)
        view.anchor(height: 6, width: 6)
        view.layer.cornerRadius = 6/2
        return view
    }()
    
    private let linkingView: UIView = {
        let view = UIView()
        view.backgroundColor = .init(white: 0.5, alpha: 1)
        return view
    }()
    
    private let destinationIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .init(white: 0.3, alpha: 1)
        return view
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addShadow()
        backgroundColor = .white
        addSubview(backButton)
        backButton.anchor(top: safeAreaLayoutGuide.topAnchor, left: leftAnchor, paddingTop: 8, paddingLeft: 12, height: 25, width: 24)
        
        addSubview(titleLabel)
        titleLabel.centerY(inView: backButton)
        titleLabel.centerX(inView: self)
        
        addSubview(startingLocationTextField)
        startingLocationTextField.anchor(top: backButton.bottomAnchor, left: leftAnchor, right: rightAnchor, paddingTop: 4, paddingLeft: 40, paddingRight: 20, height: 30)
        
        addSubview(destinationLocationTextField)
        destinationLocationTextField.anchor(top: startingLocationTextField.bottomAnchor, left: startingLocationTextField.leftAnchor, right: startingLocationTextField.rightAnchor, paddingTop: 12, height: 30)
        
        addSubview(startIndicatorView)
        startIndicatorView.centerY(inView: startingLocationTextField)
        startIndicatorView.centerX(inView: backButton)

        
        addSubview(destinationIndicatorView)
        destinationIndicatorView.centerY(inView: destinationLocationTextField)
        destinationIndicatorView.centerX(inView: backButton)
        destinationIndicatorView.anchor(height: 6, width: 6)
        destinationIndicatorView.layer.cornerRadius = 6/2
        
        addSubview(linkingView)
        linkingView.centerX(inView: backButton)
        linkingView.anchor(top: startIndicatorView.bottomAnchor, bottom: destinationIndicatorView.topAnchor, paddingTop: 4, paddingBottom: 4, width: 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Selectors
    
    @objc func handleBackTapped() {
        delegate?.dismissLocationInputView()
    }
    
}

// MARK: - UITextFieldDelegate

extension LocationInputView: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let query = textField.text else { return false }
        delegate?.executeSearch(query: query)
        return true
    }
}
