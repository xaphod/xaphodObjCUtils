#
# Be sure to run `pod lib lint filename.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "xaphodObjCUtils"
  s.version          = "0.0.11"
  s.summary          = "Xaphod's Objective-C utility pod"
  s.description      = <<-DESC
			A collection of obj-c utils I don't want in my swift-only projects
                       DESC
  s.homepage         = "https://github.com/xaphod/xaphodObjCUtils"
  s.license          = 'MIT'
  s.author           = { "Tim Carr" => "xaphod@gmail.com" }
  s.source           = { :git => "https://github.com/xaphod/xaphodObjCUtils.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.1'
  s.requires_arc = true
  s.source_files = 'Pod/Classes/*.{m,h}'
  s.library = 'z'

  s.subspec 'CocoaRunloopSocket' do |crs|
    crs.source_files = 'Pod/Classes/CocoaRunloopSocket/*.{m,h}'
    crs.requires_arc = true
  end

  s.subspec 'RXTimer' do |rx|
    rx.source_files = 'Pod/Classes/RXTimer/*.{m,h}'
    rx.requires_arc = true
  end

  #s.resource_bundles = {
  #  'Bluepeer' => ['Pod/Assets/*.{lproj,storyboard}']
  #}
  #s.public_header_files = 'Pod/Classes/*.h'
  #s.xcconfig = {'OTHER_LDFLAGS' => '-ObjC -all_load'}
  #s.prefix_header_file = 'Pod/Classes/EOSFTPServer-Prefix.pch'
  #s.pod_target_xcconfig = {'SWIFT_INCLUDE_PATHS' => '$(SRCROOT)/Bluepeer/Pod/**'}
  #s.preserve_paths = 'Pod/Classes/module.modulemap'
end
