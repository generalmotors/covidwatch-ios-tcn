/*******************************************************************************
* IntroScreenViewController.swift
*
* Title:			Contact Tracing
* Description:		Contact Tracing Monitoring and Reporting App
*						This file contains the view controller for the intro screen
* Author:			Eric Crichlow
* Version:			1.0
********************************************************************************
*	05/13/20		*	EGC	*	File creation date
*******************************************************************************/

import UIKit
import CoreLocation
import CoreBluetooth

class IntroScreenViewController: UIViewController {

    @IBOutlet weak var permissionsButton: UIButton!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var containerView: UIView!

    private var centralManager: CBCentralManager!
    private var bluetoothAuthorization: CBManagerAuthorization = .notDetermined {
        didSet {
            showNextScreenIfNecessary()
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	// MARK: View Lifecycle

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        phoneTextField.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        setupObservers()
        runPermissionsCheck()
        phoneTextField.text = KeychainManager.read(key: .phoneNumberKey)
    }

    @IBAction func grantPermission(_ sender: UIButton) {
        centralManager = CBCentralManager(delegate: self, queue: nil)

        if bluetoothAuthorization == .denied, let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func handleNotification(notification: Notification) {
        switch notification.name {
        case UIResponder.keyboardWillShowNotification:
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

            var frameWithKeyboard = view.frame
            frameWithKeyboard.size.height -= keyboardFrame.size.height
            let textFieldFrame = view.convert(phoneTextField.frame, from: containerView)

            if !frameWithKeyboard.contains(textFieldFrame) {
                let heightAdjustment = textFieldFrame.origin.y + textFieldFrame.size.height - frameWithKeyboard.size.height + 8
                view.frame.origin.y -= heightAdjustment
            }
        case UIResponder.keyboardWillHideNotification:
            view.frame.origin.y = 0
        default:
            break
        }
    }

    @objc private func dismissKeyboard() {
        phoneTextField.resignFirstResponder()
    }

    private func runPermissionsCheck() {
        if #available(iOS 13.1, *) {
            bluetoothAuthorization = CBCentralManager.authorization
        } else {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    private func formatPhoneNumber(textInput: String) -> String {
        let numbers = textInput.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let phoneMask = "(XXX) XXX-XXXX"

        var numberIndex = numbers.startIndex
        let formattedNumber = phoneMask.reduce("") { partialResult, character in
            guard numberIndex < numbers.endIndex else { return partialResult }
            guard character == "X" else { return "\(partialResult)\(character)" }

            let result = "\(partialResult)\(numbers[numberIndex])"
            numberIndex = numbers.index(after: numberIndex)
            return result
        }

        return formattedNumber
    }

    private func showNextScreenIfNecessary() {
        if bluetoothAuthorization == .allowedAlways,
            let phoneNumber = KeychainManager.read(key: .phoneNumberKey),
            phoneNumber.count == 14 {
            DispatchQueue.main.async {
                let showPostReport = UserDefaults.standard.bool(forKey: .postReportScreenKey)

                if showPostReport {
                    self.performSegue(withIdentifier: "postReportSegue", sender: self)
                } else {
                    self.performSegue(withIdentifier: "mainScreenSegue", sender: self)
                }
            }
        }
    }

}

// MARK: - UITextFieldDelegate
extension IntroScreenViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text,
            let textRange = Range(range, in: text) else {
                return false
        }

        let newText = text.replacingCharacters(in: textRange, with: string)
        textField.text = formatPhoneNumber(textInput: newText)

        guard let formattedText = textField.text else { return false }
        KeychainManager.set(value: formattedText, key: .phoneNumberKey)

        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else { return }
        KeychainManager.set(value: text, key: .phoneNumberKey)

        showNextScreenIfNecessary()
    }

}

// MARK: - CBCentralManagerDelegate
extension IntroScreenViewController: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothAuthorization = central.authorization
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any])
    {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBCentralManager will restore state"))
    }

}
