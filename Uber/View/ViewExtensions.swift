//
//  ViewExtensions.swift
//  Uber
//
//  Created by Miks Freibergs on 15/06/2020.
//  Copyright © 2020 Miks Freibergs. All rights reserved.
//

import UIKit

extension UIView {
    
    func inputContainerView(image: UIImage, textField: UITextField? = nil, segmentedControl: UISegmentedControl? = nil) -> UIView {
        let view = UIView()
        
        let seperatorView = UIView()
        seperatorView.backgroundColor = .lightGray
        view.addSubview(seperatorView)
        
        let imageView = UIImageView()
        imageView.image = image
        imageView.alpha = 0.87
        view.addSubview(imageView)
     
        if let textField = textField {
            imageView.centerY(inView: view)
            imageView.anchor(left: view.leftAnchor, height: 24, width: 24)
            
            view.addSubview(textField)
            textField.centerY(inView: view)
            textField.anchor(left: imageView.rightAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingLeft: 8)
            seperatorView.anchor(top: textField.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, height: 0.75)
            view.anchor(height: 50)
        }
        
        if let sc = segmentedControl {
            imageView.anchor(left: view.leftAnchor, height: 24, width: 24)
            view.addSubview(sc)
            sc.anchor(left: view.leftAnchor, right: view.rightAnchor)
            seperatorView.anchor(top: sc.bottomAnchor, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingTop: 12, height: 0.75)
            view.anchor(height: 80)
        }
        
        return view
    }
    
    func addShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        layer.masksToBounds = false

    }
}

extension UITextField {
    
    func textField(withPlaceholder placeholder: String, isSecureTextEntry: Bool) -> UITextField {
        let tf = UITextField()
        tf.borderStyle = .none
        tf.font = .systemFont(ofSize: 16)
        tf.textColor = .white
        tf.isSecureTextEntry = isSecureTextEntry
        tf.keyboardAppearance = .dark
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [NSAttributedString.Key.foregroundColor : UIColor.lightGray])
        return tf
    }
}

extension UIButton {
    
    func authButton(withTitle title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor.init(white: 1, alpha: 0.5), for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.layer.cornerRadius = 5
        button.backgroundColor = .mainBlueTint
        button.anchor(height: 50)
        return button
    }
    
    func haveAccountButton(firstSring: String, secondString: String) -> UIButton {
        let button = UIButton(type: .system)
        let attributedTitle = NSMutableAttributedString(string: firstSring, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: secondString, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: UIColor.mainBlueTint]))
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }
}
