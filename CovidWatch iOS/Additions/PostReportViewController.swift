//
//  PostReportViewController.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 5/19/20.
//

import UIKit

class PostReportViewController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()

        UserDefaults.standard.setValue(true, forKey: .postReportScreenKey)
    }

    @IBAction func coronaFreePress(_ sender: UIButton) {
        UserDefaults.standard.set(false, forKey: .postReportScreenKey)

        if let viewControllers = navigationController?.viewControllers,
            let mainScreenViewController = viewControllers.first(where: { $0 is MainScreenViewController }) {
            // Navigated from the main screen
            navigationController?.popToViewController(mainScreenViewController, animated: true)
        } else {
            // Fresh launch and navigated from the intro screen
            self.performSegue(withIdentifier: "mainScreenSegue", sender: self)
        }
    }
    
}

extension String {

    static let postReportScreenKey = "onPostReport"

}
