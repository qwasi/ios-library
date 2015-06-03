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
  s.version          = "2.1.0"
  s.summary          = "Qwasi iOS Library"
  s.homepage         = "https://code.qwasi.com/scm/sdk/ios-library"
  s.license          = 'MIT'
  s.author           = { "Rob Rodriguez" => "rob.rodriguez@qwasi.com" }
  s.source           = { :git => "https://code.qwasi.com/scm/sdk/ios-library.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'Qwasi' => ['Pod/Assets/*.png']
  }

end
