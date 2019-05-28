//
//  PasswordlessViewController.swift
//  CognitoYourUserPoolsSample
//
//  Created by Dean Holdren on 5/22/19.
//  Copyright © 2019 Dubal, Rohan. All rights reserved.
//

import Foundation

import AWSCognitoIdentityProvider

class PasswordlessViewController: UIViewController {
    
    var destination: String?
    var customAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityCustomChallengeDetails>?
    var user: AWSCognitoIdentityUser?
    var username: String?
    var signinViewController: UIViewController?
    
    @IBOutlet weak var sentTo: UILabel!
    @IBOutlet weak var confirmationCode: UITextField!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.sentTo.text = "Code sent to: \(self.destination!)"
        self.confirmationCode.text = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // perform any action, if required, once the view is loaded
    }
    
    @IBAction func signIn(_ sender: AnyObject) {
        // check if the user is not providing an empty authentication code
        guard let authenticationCodeValue = self.confirmationCode.text, !authenticationCodeValue.isEmpty else {
            let alertController = UIAlertController(title: "Authentication Code Missing",
                                                    message: "Please enter the authentication code you received by E-mail / SMS.",
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            
            self.present(alertController, animated: true, completion:  nil)
            return
        }

        performSetConfirmationCode(code: self.confirmationCode!.text!)
    }
    
    func performSetConfirmationCode(code: String){
        self.customAuthenticationCompletion?.set(result: AWSCognitoIdentityCustomChallengeDetails(challengeResponses: [
            "ANSWER" : code,
            "USERNAME" : self.username!
            ]))
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
            self.signinViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
}
