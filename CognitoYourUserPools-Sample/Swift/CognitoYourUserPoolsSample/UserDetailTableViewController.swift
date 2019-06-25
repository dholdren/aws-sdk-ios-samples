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
import AWSIoT

class UserDetailTableViewController : UITableViewController, AWSIdentityProviderManager {
    
    @IBOutlet weak var currentTempLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var slider: UISlider!
    var response: AWSCognitoIdentityUserGetDetailsResponse?
    var user: AWSCognitoIdentityUser?
    var pool: AWSCognitoIdentityUserPool?
    var awsCognitoCredentialsProvider: AWSCognitoCredentialsProvider?
    var identityId: String?
    var sessionIdTokenString: String?
    var thingName: String?
    var targetTemp: Float?
    var currentTemp: Float?
    

    @objc var iotDataManager: AWSIoTDataManager!
    @objc var iotManager: AWSIoTManager!
    @objc var iot: AWSIoT!
    @objc var connected = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        
        self.pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
        self.awsCognitoCredentialsProvider = AWSCognitoCredentialsProvider(regionType: .USEast2, identityPoolId: CognitoIdentityPoolId)
        self.awsCognitoCredentialsProvider?.setIdentityProviderManagerOnce(self)
        self.awsCognitoCredentialsProvider?.identityProvider.clear()
        self.awsCognitoCredentialsProvider?.clearKeychain()


        // Init IOT
        let iotEndPoint = AWSEndpoint(urlString: IOT_ENDPOINT)

        // Configuration for AWSIoT control plane APIs
        let iotConfiguration = AWSServiceConfiguration(region: .USEast2, credentialsProvider: self.awsCognitoCredentialsProvider)

        // Configuration for AWSIoT data plane APIs
        let iotDataConfiguration = AWSServiceConfiguration(region: .USEast2,
                endpoint: iotEndPoint,
                credentialsProvider: self.awsCognitoCredentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = iotConfiguration

        self.iotManager = AWSIoTManager.default()
        self.iot = AWSIoT.default()

        AWSIoTDataManager.register(with: iotDataConfiguration!, forKey: ASWIoTDataManagerKey)
        self.iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManagerKey)

        if (self.user == nil) {
            self.user = self.pool?.currentUser()
        }
        self.refresh()
    }

    @IBAction func setTargetTemp(_ sender: Any) {
        let deviceName = getThings()[0]
        updateDeviceShadow(name: deviceName, targetTemp: self.slider.value.rounded())
    }
    

    @IBAction func textFieldChanged(_ sender: Any) {
        //print("text field changed: \(self.textField.text!)")
        let localTargetTemp = Float(self.textField.text!)?.rounded()
        
        if (localTargetTemp != nil) {
            self.targetTemp = localTargetTemp
            self.textField.text = String(self.targetTemp!) //in case it was rounded
            slider.value = self.targetTemp!
        } else {
            //change it back, must have entered a non-number
            textField.text = String(Int(slider.value))
        }
    }

    @IBAction func sliderValueChanged(_ sender: Any) {
        //print("slider changed: =\(slider.value)")
        let localTargetTemp = self.slider.value.rounded()
        self.targetTemp = localTargetTemp
        textField.text = String(Int(self.targetTemp!))
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
            //should get or create ID in identity pool
            self.awsCognitoCredentialsProvider?.identityProvider.getIdentityId().continueWith(block: { (task) -> Any? in
                if let identityId = task.result {
                    print("successfully created/retrieved identity pool entry: \(identityId)")
                    self.identityId = identityId as String
                } else {
                    print(task.error)
                }
                return nil
            })
            //attach the IOT policy to the identity
            //TODO: make a new "Pairing" service and do this during that operation.
            //don't give the user attachpolicy provisions
            self.attachPrincipalPolicy()
            DispatchQueue.main.async(execute: {
                self.response = task.result
                self.title = self.user?.username
                self.tableView.reloadData()
            })

            //device shadow setup
            let uuid = UUID().uuidString;
            self.iotDataManager.connectUsingWebSocket(withClientId: uuid, cleanSession: true, statusCallback: { ( _ status: AWSIoTMQTTStatus ) -> Void in
                    if status == .connected {
                        print( "Connected" )
                        for thingName in self.getThings() {
                            print("registering the device shadow for: \(thingName)")
                            self.iotDataManager.register(withShadow: thingName, options: ["enableDebugging" : true], eventCallback: self.deviceShadowCallback)
                            self.iotDataManager.getShadow(thingName, clientToken: uuid) //should call registered callback
                        }
                    } else {
                        print("Not connected, \(status.rawValue)")
                    }
                }
            )
            
            return nil
        }
    }

    func attachPrincipalPolicy() {

        // get the AWS Cognito Identity

        self.awsCognitoCredentialsProvider?.identityProvider.getIdentityId().continueWith { task -> Any? in

            if let error = task.error {
                print(error.localizedDescription)
                return task
            }

            guard let attachPrincipalPolicyRequest = AWSIoTAttachPrincipalPolicyRequest(), let principal = task.result else {
                return task
            }

            // The AWS IoT Policy
            attachPrincipalPolicyRequest.policyName = PolicyName
            // The AWS Cognito Identity
            attachPrincipalPolicyRequest.principal = String(principal)

            AWSIoT.default().attachPrincipalPolicy(attachPrincipalPolicyRequest, completionHandler: { error in
                if let error = error {
                    print(error.localizedDescription)
                }
            })

            return task
        }
    }

    //match expected signature of `self.awsCognitoCredentialsProvider?.setIdentityProviderManagerOnce(self)`
    public func logins() -> AWSTask<NSDictionary> {
        let dict = NSMutableDictionary.init()
        dict[self.pool?.identityProviderName] = self.sessionIdTokenString
        let task = AWSTask.init(result: dict as NSDictionary)
        return task
    }

    //retrieve things associated with this user from our
    //pairing service (mock for now)
    func getThings() -> [String] {
        return ["esp32_devkitc_dean1"]
    }

    func updateDeviceShadow(name: String, targetTemp: Float) {
        print("setting updateDeviceShadown, targetTemp: \(targetTemp)")
        let json = deviceShadowJsonString(targetTemp: targetTemp)
        self.iotDataManager.updateShadow(name, jsonString: json)
    }
    
    // operation: 0 = Update, 1 = Get, 2 = Delete
    // status: 0 = Accepted, 1 = Rejected, 2 = Delta, 3 = Documents, 5 = ForeignUpdate, 6 = Timeout
    func deviceShadowCallback(name: String, operation: AWSIoTShadowOperationType, status: AWSIoTShadowOperationStatusType, clientToken: String, payload: Data) {
        let payloadStringValue = NSString(data: payload, encoding: String.Encoding.utf8.rawValue)!
        
        print("in device Shadow Callback")
        print("********************************")
        print(name)
        print(operation.rawValue)
        print(status.rawValue)
        print(clientToken)
        print(payloadStringValue)
        print("********************************")
        
        let currentTemp: NSNumber?
        let targetTemp: NSNumber?
        do {
            let jsonPayload = try JSONSerialization.jsonObject(with:
                payload, options: [])
            let jsonRoot = jsonPayload as! [String: Any]
            var shouldUpdateView = false
            
            if (operation == .update || operation == .get) {
                if (status == .accepted) {
                    let jsonState = jsonRoot["state"] as! [String: Any]
                    let jsonDesired = jsonState["desired"] as! [String: Any]?
                    let jsonReported = jsonState["reported"] as! [String: Any]?
                    let jsonObj = (jsonReported ?? jsonDesired)!
                    targetTemp = jsonObj["target_temp"] as! NSNumber?
                    currentTemp = jsonObj["current_temp"] as! NSNumber?
                    
                    updateTempValues(targetTemp: targetTemp, currentTemp: currentTemp)
                } else if (status == .delta) {
                    let jsonState = jsonRoot["state"] as! [String: Any]
                    targetTemp = jsonState["target_temp"] as! NSNumber?
                    currentTemp = jsonState["current_temp"] as! NSNumber?
                    
                    updateTempValues(targetTemp: targetTemp, currentTemp: currentTemp)
                } else if (status == .documents) {
                    let jsonCurrent = jsonRoot["current"] as! [String: Any]
                    let jsonState = jsonCurrent["state"] as! [String: Any]
                    let jsonDesired = jsonState["desired"] as! [String: Any]?
                    let jsonReported = jsonState["reported"] as! [String: Any]?
                    let jsonObj = (jsonReported ?? jsonDesired)!
                    targetTemp = jsonObj["target_temp"] as! NSNumber?
                    currentTemp = jsonObj["current_temp"] as! NSNumber?
                    
                    updateTempValues(targetTemp: targetTemp, currentTemp: currentTemp)
                }
            }
        } catch let parsingError {
            print("Error", parsingError)
        }
    }
    
    func deviceShadowJsonString(targetTemp: Float) -> String {
        return "{\"state\" : {\"desired\": {\"target_temp\": \(String(targetTemp)) }}}"
    }
    
    func updateTempValues(targetTemp: NSNumber?, currentTemp: NSNumber?) -> Void {
        if let targetTemp = targetTemp {
            self.targetTemp = targetTemp.floatValue
            self.currentTemp = currentTemp?.floatValue ?? self.currentTemp
            
            DispatchQueue.main.async(execute: {
                
                self.slider.value = self.targetTemp!
                self.textField.text = String(self.targetTemp!)
                self.currentTempLabel.text = "Current Temp: \(self.currentTemp ?? 0.0), Target Temp: \(self.targetTemp ?? 0.0)"
            })
        } else {
            print("missing targetTemp in JSON")
        }
    }
}

