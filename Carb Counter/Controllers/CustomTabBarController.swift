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

        // Set the background image and shadow image to empty images to make the tab bar transparent
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        
        // Set the tab bar background color to clear
        tabBar.barTintColor = UIColor.clear
        tabBar.isTranslucent = true
        
        // Customize the tab bar item appearance
        tabBar.tintColor = UIColor.label
        tabBar.unselectedItemTintColor = UIColor.label.withAlphaComponent(0.5)
    }
}
