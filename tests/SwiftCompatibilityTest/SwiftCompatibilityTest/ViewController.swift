/*
 *
 *    Copyright 2018 APPNEXUS INC
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

import UIKit
import EplanningSDK

class ViewController: UIViewController, ANBannerAdViewDelegate {
    
    @IBOutlet var banner:ANBannerAdView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        banner = ANBannerAdView(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
        banner.adSize = CGSize(width: 300, height: 250)
        banner.placementId = "12345"
        banner.gender = .female
        banner.age = "18 - 24"
        banner.rootViewController = self;
        banner.delegate = self
        banner.loadAd()
        
    }
    
    //delegate methods
    func adDidReceiveAd(_ ad: Any) {
        print("adDidReceiveAd");
    }
    func ad(_ ad: Any, requestFailedWithError error: Error) {
        print("Ad requestFailedWithError");
        
    }
    
    func adWasClicked(_ ad: Any, withURL urlString: String) {
        print(ad)
    }

}
