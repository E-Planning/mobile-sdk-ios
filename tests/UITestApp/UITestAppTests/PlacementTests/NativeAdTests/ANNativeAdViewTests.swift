/*   Copyright 2019 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


import XCTest
import EplanningSDK

class ANNativeAdViewTests: XCTestCase {
    
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        continueAfterFailure = false
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testRTBNative() {
        
        let adObject = AdObject(adType: "Native", accessibilityIdentifier: PlacementTestConstants.NativeAd.testRTBNative, placement: "16392991")
        let nativeAdObject =  NativeAdObject(shouldLoadIconImage: true, shouldLoadMainImage: true, adObject: adObject)
        
        
        let nativeAdObjectString =  AdObjectModel.encodeNativeObject(adObject: nativeAdObject)

        let app = XCUIApplication()
        app.launchArguments.append(PlacementTestConstants.NativeAd.testRTBNative)
        app.launchArguments.append(nativeAdObjectString)
        app.launch()
        
  
        let element = app.otherElements.containing(.navigationBar, identifier:"Native Ad").children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element
      
        wait(for: element, timeout: 20)

        element.tap()
        
        let nativeTitle = app.staticTexts["NativeAd UI Test"]
        XCTAssertEqual(nativeTitle.exists, true)
        
        let nativeBody = app.staticTexts["Spot testing is working using UI test"]
        XCTAssertEqual(nativeBody.exists, true)
        
        let nativeSponsored = app.staticTexts["UITestApp"]
        XCTAssertEqual(nativeSponsored.exists, true)
       
        let icon_image = element.children(matching: .image).element(boundBy: 0)
        XCTAssertEqual(icon_image.exists, true)
        XCTAssertGreaterThan(icon_image.frame.size.width, 40)
        XCTAssertGreaterThan(icon_image.frame.size.height, 40)
        
        let main_image = element.children(matching: .image).element(boundBy: 1)
        XCTAssertEqual(main_image.exists, true)
        XCTAssertGreaterThan(main_image.frame.size.width, 200)
        XCTAssertGreaterThan(main_image.frame.size.height, 200)

        wait(2)
        
        let nativeClickButton = app.buttons["ANNativeAdViewCallToAction"]
        XCTAssertEqual(nativeClickButton.exists, true)
        nativeClickButton.tap()
        app/*@START_MENU_TOKEN@*/.toolbars["Toolbar"]/*[[".otherElements[\"In App Browser\"].toolbars[\"Toolbar\"]",".toolbars[\"Toolbar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.buttons["OK"].tap()
        XCGlobal.screenshotWithTitle(title: PlacementTestConstants.NativeAd.testRTBNative)
        wait(2)
    }
    

 
}


