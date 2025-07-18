require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "ImagePicker"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "n/a"
  s.license      = "Copyright © 2024 Calico Games. All rights reserved."
  s.authors      = { "Sebastien Menozzi" => "seb@calico.games" }
  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "n/a", :tag => "#{s.version}" }

  s.requires_arc = true

  s.dependency 'React-Core'
  s.dependency 'SDWebImage', '~> 5.21.1'
  s.dependency 'SDWebImageWebPCoder', '~> 0.14.6'
  s.dependency 'TOCropViewController', '~> 2.7.4'

  s.source_files = 'ios/*.{h,m,swift}'

  s.resource_bundles = {
    'ImagePickerPrivacyInfo' => ['ios/PrivacyInfo.xcprivacy'],
  }

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end