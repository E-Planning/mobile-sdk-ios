Pod::Spec.new do |s|

  s.name         = "EplanningSDK"
  s.version      = "8.11.0"
  s.platform     = :ios, "12.0"

  s.summary      = "Eplanning iOS Mobile Advertising SDK"
  s.description  = <<-DESC
Our mobile advertising SDK gives developers a fast and convenient way to monetize their apps.
DESC

  s.homepage     = "https://github.com/appnexus/mobile-sdk-ios"
  s.source       = { :git => "https://github.com/appnexus/mobile-sdk-ios.git", :branch => "master" }
  s.author       = { "Eplanning Mobile Engineering" => "sdk@appnexus.com" }
  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }

  s.requires_arc = true
  s.static_framework = true
  s.default_subspec = 'EplanningSDK'

  s.subspec 'EplanningSDK' do |subspec|
    subspec.source_files         = "sdk/sourcefiles/**/*.{h,m}"
    subspec.public_header_files  = "sdk/sourcefiles/public-headers/*.h"
    subspec.resources            = "sdk/sourcefiles/Resources/*.{png,xib,nib,js,html,bundle,strings}","sdk/sourcefiles/Resources/images/*.{png}","sdk/EplanningSDK/SDK-Info.plist"
    subspec.vendored_frameworks   =  "sdk/sourcefiles/Viewability/dynamic_framework/OMSDK_Microsoft.xcframework"
    subspec.frameworks           = 'WebKit'
    subspec.pod_target_xcconfig = { "VALID_ARCHS[sdk=iphoneos*]": "arm64 armv7", "VALID_ARCHS[sdk=iphonesimulator*]": "x86_64 arm64" }
    subspec.exclude_files = "sdk/sourcefiles/macOS/", "sdk/sourcefiles/Viewability/static_framework","sdk/sourcefiles/Viewability/dynamic_framework"

  end

  s.subspec 'GoogleAdapter' do |subspec|
    subspec.dependency  'EplanningSDK/EplanningSDK', "#{s.version}"
    subspec.dependency  'Google-Mobile-Ads-SDK', '10.10.0'
    subspec.source_files         = "mediation/mediatedviews/GoogleAdMob/*.{h,m}"
    subspec.public_header_files  = "mediation/mediatedviews/GoogleAdMob/ANGoogleMediationSettings.h"
    subspec.xcconfig              = { 'FRAMEWORK_SEARCH_PATHS' => '${PODS_ROOT}/Google-Mobile-Ads-SDK/**' }
  end

  s.subspec 'FacebookCSRAdapter' do |subspec|
    subspec.dependency  'EplanningSDK/EplanningSDK', "#{s.version}"
    subspec.dependency 'FBAudienceNetwork', '6.14.0'
    subspec.source_files         = "csr/Facebook/*.{h,m}"
    subspec.public_header_files  = "csr/Facebook/*.h"
    subspec.xcconfig              = { 'FRAMEWORK_SEARCH_PATHS' => '${PODS_ROOT}/FBAudienceNetwork/**' }
  end

  s.subspec 'SmartAdAdapter' do |subspec|
    subspec.dependency 'EplanningSDK/EplanningSDK', "#{s.version}"
    subspec.source_files = "mediation/mediatedviews/SmartAd/*.{h,m}"
    subspec.public_header_files = "mediation/mediatedviews/SmartAd/ANAdAdapterSmartAdBase.h"
    subspec.dependency 'Smart-Display-SDK', '7.22.0'
    subspec.xcconfig              = { 'FRAMEWORK_SEARCH_PATHS' => '${PODS_ROOT}/Smart-Display-SDK/**' }
  end

end