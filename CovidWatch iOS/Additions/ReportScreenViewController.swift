//
//  ReportScreenViewController.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 5/19/20.
//

import UIKit

class ReportScreenViewController: UIViewController {

    @IBOutlet weak var sendInteractionsButton: UIButton!
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sendInteractionsButton.titleLabel?.textAlignment = .center
    }

    @IBAction func dialMedicalPress(_ sender: UIButton) {
        //Dial Medical
    }
    
    @IBAction func cancel(_ sender: UIButton)
    {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func sendInteractionsPress(_ sender: UIButton) {
        UserDefaults.shared.setValue(true, forKey: UserDefaults.Key.isUserSick)
        UserDefaults.shared.setValue(Date(), forKey: UserDefaults.Key.testLastSubmittedDate)

        sendPhoneNumber()
    }

    func sendPhoneNumber(number: String? = KeychainManager.read(key: .phoneNumberKey), attempt: Int = 0) {
        guard let phoneNumber = number,
            attempt < AppConfigurationManager.defaultWebRequestRetries else {
                return
        }
        let submitRequest = SubmitPhoneNumberRequest(phoneNumber: phoneNumber, isPrimary: true)
        Network.request(router: submitRequest) { (result: Result<SubmitPhoneNumberModel, Error>) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "postReportSegue", sender: nil)
                }
            case .failure(_):
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: DispatchTime.now() + AppConfigurationManager.webRequestRetryDelay) {
                    self.sendPhoneNumber(number: phoneNumber, attempt: attempt + 1)
                }
            }
        }
    }
    
}
