#
# Be sure to run `pod lib lint Qwasi.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Qwasi"
  s.version          = "2.1.16-dev.142"
  s.summary          = "Qwasi iOS Library"
  s.homepage         = "https://github.com/qwasi/ios-library"
  s.license          = 'MIT'
  s.author           = { "Rob Rodriguez" => "rob.rodriguez@qwasi.com" }
  s.source           = { :git => "https://github.com/qwasi/ios-library.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.ios.deployment_target = '7.1'
  s.ios.framework = 'CoreLocation'

  s.public_header_files = 'Pod/**/*.h'

  s.source_files = 'Pod/**/*'

  s.dependency 'CocoaLumberjack', '2.0.0'
  s.dependency 'AFNetworking'
  s.dependency 'GBDeviceInfo', '~> 3.1.0'
  s.dependency 'Emitter'
  s.dependency 'QSwizzle', '~> 0.2.0'
end
