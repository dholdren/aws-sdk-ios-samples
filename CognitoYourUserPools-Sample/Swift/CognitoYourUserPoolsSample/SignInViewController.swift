//
// Copyright 2014-2018 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License").
// You may not use this file except in compliance with the
// License. A copy of the License is located at
//
//     http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, express or implied. See the License
// for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import AWSCognitoIdentityProvider

class SignInViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var username: UITextField!
    //@IBOutlet weak var password: UITextField!
    var customAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityCustomChallengeDetails>?
    var usernameText: String?
    var passwordlessViewController : PasswordlessViewController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //so we can hide keyboard
        self.username.delegate = self
        //self.password.delegate = self
        
        //self.password.text = nil
        self.username.text = usernameText
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    //hide keyboard when we touch outside of the keyboard
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    @IBAction func signInPressed(_ sender: AnyObject) {
        if (self.username.text != nil ) {
            //if you ever logged in, the username sticks around in persistent storage after you signed-out
            //this is useful for potentially pre-populating the text field, but breaks log-in since the SDK uses this value
            AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey).clearLastKnownUser()
            self.usernameText = self.username.text
            
            //first attempt signup, then signin
            attemptSignup(self.usernameText!) { () in
                
                let details = AWSCognitoIdentityCustomChallengeDetails.init(challengeResponses: ["USERNAME" : self.usernameText!])
                self.customAuthenticationCompletion?.set(result: details)
            }
        } else {
            let alertController = UIAlertController(title: "Missing information",
                                                    message: "Please enter a valid user name",
                                                    preferredStyle: .alert)
            let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
            alertController.addAction(retryAction)
        }
    }

    func performSetConfirmationCode(code: String){
        self.customAuthenticationCompletion?.set(result: AWSCognitoIdentityCustomChallengeDetails(challengeResponses: [
            "ANSWER" : code,
            "USERNAME" : self.username.text!
            ]))
        DispatchQueue.main.async {
            self.passwordlessViewController?.dismiss(animated: true, completion: nil)
            self.dismiss(animated: true, completion: nil)
        }
    }

    func attemptSignup(_ userNameValue: String, completion: @escaping () -> (Void)) {
        var attributes = [AWSCognitoIdentityUserAttributeType]()
        
        let email = AWSCognitoIdentityUserAttributeType()
        email?.name = "email"
        email?.value = userNameValue
        attributes.append(email!)
        
        let passwordValue = randomString(30)
        let pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
        pool.signUp(userNameValue, password: passwordValue, userAttributes: attributes, validationData: nil).continueWith { (task) -> Any? in
            if let error = task.error as NSError? {
                //assume the error is that the user exists, ignore
                print(error)
            } else if let result = task.result  {
                print(result)
            }
//            if (completion != nil) {
                completion()
//            }
            return nil
        }
    }
    
    func randomString(_ length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
}

extension SignInViewController: AWSCognitoIdentityCustomAuthentication {
    
    
    func getCustomChallengeDetails(_ authenticationInput: AWSCognitoIdentityCustomAuthenticationInput, customAuthCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityCustomChallengeDetails>) {
        self.customAuthenticationCompletion = customAuthCompletionSource
        
        //this is the re-entry after clickin sign-in
        if (authenticationInput.challengeParameters.count > 0) {
            print("challengeParameters present")
            print(authenticationInput.challengeParameters)
            
            if (self.passwordlessViewController == nil) {
                self.passwordlessViewController = PasswordlessViewController()
            }
            self.passwordlessViewController!.modalPresentationStyle = .popover
            self.passwordlessViewController!.customAuthenticationCompletion = customAuthCompletionSource
            self.passwordlessViewController!.destination = authenticationInput.challengeParameters["email"]
            self.passwordlessViewController!.username = authenticationInput.challengeParameters["USERNAME"]
            
            //so we can dismiss both
            self.passwordlessViewController?.signinViewController = self
            
            DispatchQueue.main.async {
                if (!self.passwordlessViewController!.isViewLoaded
                    || self.passwordlessViewController!.view.window == nil) {
                    //display passwordless as popover on current view controller
                    self.present(self.passwordlessViewController!,
                                            animated: true,
                                            completion: nil)
                    
                    // configure popover vc
                    let presentationController = self.passwordlessViewController!.popoverPresentationController
                    presentationController?.permittedArrowDirections = UIPopoverArrowDirection.left
                    presentationController?.sourceView = self.view
                    presentationController?.sourceRect = self.view.bounds
                }
            }
        }
    }
    
    public func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async {
            if let error = error as NSError? {
                let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                        message: error.userInfo["message"] as? String,
                                                        preferredStyle: .alert)
                let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                alertController.addAction(retryAction)
                
                self.present(alertController, animated: true, completion:  nil)
            }
        }
    }
}
