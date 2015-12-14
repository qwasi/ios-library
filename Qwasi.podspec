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
  s.version          = "2.1.18-dev.171"
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

  s.dependency 'AFNetworking', '~>2.6.3'
  s.dependency 'GBDeviceInfo', '~> 3.5.1'
  s.dependency 'QSwizzle', '~> 0.2.0'
  s.dependency 'BlocksKit'
end
