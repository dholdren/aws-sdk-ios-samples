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

let CognitoIdentityUserPoolRegion: AWSRegionType = AWSRegionType.USEast2
let CognitoIdentityUserPoolId = "us-east-2_ykDz8Q4Qn"

//1kpec is the custom-auth only
let userPassAppClientId = "215ava6g2jg9on5dvapctaqocp"
let customAuthOnlyAppClientId = "1kpec116bjij08jjdlv3rqp0h2"
//let CognitoIdentityUserPoolAppClientId = userPassAppClientId
let CognitoIdentityUserPoolAppClientId = customAuthOnlyAppClientId

let CognitoIdentityUserPoolAppClientSecret = ""

let AWSCognitoUserPoolsSignInProviderKey = "UserPool"

//identity Pool:
let CognitoIdentityPoolId = "us-east-2:018d6b1a-8e9a-45cc-8d3b-3b809aaef978"

//device shadow and telemetry
let PolicyName = "esp32_devkitc_dean1_amazon_freertos_policy"
let IOT_ENDPOINT = "https://a2wysv1o16206a-ats.iot.us-east-2.amazonaws.com"
let ASWIoTDataManagerKey = "CasperIotDataManager"

