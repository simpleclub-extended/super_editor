#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint super_keyboard.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'super_keyboard'
  s.version          = '0.0.1'
  s.summary          = 'A plugin that reports keyboard visibility and size.'
  s.description      = <<-DESC
A plugin that reports keyboard visibility and size.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'super_keyboard/Sources/super_keyboard/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'super_keyboard_privacy' => ['super_keyboard/Sources/super_keyboard/PrivacyInfo.xcprivacy']}
end
