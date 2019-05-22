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
    var customAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityCustomChallengeDetails>?
    var code: String?
    
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
        //let challengeDetails = AWSCognitoIdentityCustomChallengeDetails(challengeResponses:)
        //self.customAuthenticationCompletionSource?.set(result: authenticationCodeValue as NSString)
        self.code = authenticationCodeValue
    }
    
}

extension PasswordlessViewController : AWSCognitoIdentityCustomAuthentication {

    func getCustomChallengeDetails(_ authenticationInput: AWSCognitoIdentityCustomAuthenticationInput, customAuthCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityCustomChallengeDetails>) {
        self.customAuthenticationCompletionSource = customAuthCompletionSource
        print(String(describing: authenticationInput.challengeParameters))

        if authenticationInput.challengeParameters.count == 0 {
            print("in PasswordlessViewController, error no challengeParameters")

        } else if let code = self.code {
            print("in PasswordlessViewController, challengeParameters present")
            //todo replace with value of text field
            customAuthCompletionSource.set(result: AWSCognitoIdentityCustomChallengeDetails(challengeResponses: [
                "ANSWER" : code
            ])
            )
        } else {
            print("code missing")
        }
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async(execute: {
            if let error = error as NSError? {
                
                let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                        message: error.userInfo["message"] as? String,
                                                        preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                
                self.present(alertController, animated: true, completion:  nil)
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        })
    }
    
//    func getCode(_ authenticationInput: AWSCognitoIdentityMultifactorAuthenticationInput, mfaCodeCompletionSource: AWSTaskCompletionSource<NSString>) {
//        self.mfaCodeCompletionSource = mfaCodeCompletionSource
//        self.destination = authenticationInput.destination
//    }
    
}
