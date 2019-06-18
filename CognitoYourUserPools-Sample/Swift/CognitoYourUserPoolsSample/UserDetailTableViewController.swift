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

class UserDetailTableViewController : UITableViewController, AWSIdentityProviderManager {
    
    var response: AWSCognitoIdentityUserGetDetailsResponse?
    var user: AWSCognitoIdentityUser?
    var pool: AWSCognitoIdentityUserPool?
    var awsCognitoCredentialsProvider: AWSCognitoCredentialsProvider?
    var identityId: String?
    var sessionIdTokenString: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
        self.awsCognitoCredentialsProvider = AWSCognitoCredentialsProvider(regionType: .USEast2, identityPoolId: CognitoIdentityPoolId)
        self.awsCognitoCredentialsProvider?.setIdentityProviderManagerOnce(self)
        self.awsCognitoCredentialsProvider?.identityProvider.clear()
        self.awsCognitoCredentialsProvider?.clearKeychain()
        if (self.user == nil) {
            self.user = self.pool?.currentUser()
        }
        self.refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setToolbarHidden(true, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: true)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let response = self.response  {
            return response.userAttributes!.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "attribute", for: indexPath)
        let userAttribute = self.response?.userAttributes![indexPath.row]
        cell.textLabel!.text = userAttribute?.name
        cell.detailTextLabel!.text = userAttribute?.value
        return cell
    }
    
    // MARK: - IBActions
    
    @IBAction func signOut(_ sender: AnyObject) {
        self.user?.signOut()
        self.pool?.clearLastKnownUser()
        self.title = nil
        self.response = nil
        self.tableView.reloadData()
        self.refresh()
    }
    
    func refresh() {
        self.user?.getDetails().continueOnSuccessWith { (task) -> AnyObject? in
            self.user?.getSession().continueWith(block: { (task) -> Any? in
                if let session = task.result {
                    self.sessionIdTokenString = session.idToken!.tokenString
                } else {
                    print(task.error)
                }
                return nil
            })
            //should get or create in identity pool
            self.awsCognitoCredentialsProvider?.identityProvider.getIdentityId().continueWith(block: { (task) -> Any? in
                if let identityId = task.result {
                    print("successfully created/retrieved identity pool entry: \(identityId)")
                    self.identityId = identityId as String
                } else {
                    print(task.error)
                }
                return nil
            })
            DispatchQueue.main.async(execute: {
                self.response = task.result
                self.title = self.user?.username
                self.tableView.reloadData()
            })
            return nil
        }
    }

    //match expected signature of `self.awsCognitoCredentialsProvider?.setIdentityProviderManagerOnce(self)`
    public func logins() -> AWSTask<NSDictionary> {
        let dict = NSMutableDictionary.init()
        dict[self.pool?.identityProviderName] = self.sessionIdTokenString
        let task = AWSTask.init(result: dict as NSDictionary)
        return task
    }
    
}

