//
//  SettingsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-21.
//

import UIKit

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if indexPath.row == 0 {
            cell.textLabel?.text = "Carb Ratio Schedule"
        } else {
            cell.textLabel?.text = "Start Dose Schedule"
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewController: UIViewController
        if indexPath.row == 0 {
            viewController = CarbRatioViewController()
        } else {
            viewController = StartDoseViewController()
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
}
