//
//  CustomTabBarController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-07-09.
//
import UIKit

class CustomTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.barTintColor = UIColor.clear
        tabBar.isTranslucent = true
        tabBar.tintColor = UIColor.label
        tabBar.unselectedItemTintColor = UIColor.label.withAlphaComponent(0.3)
    }
}
