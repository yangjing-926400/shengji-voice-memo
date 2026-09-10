#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

root = File.expand_path(__dir__)
project_path = File.join(root, 'Shengji.xcodeproj')
FileUtils.rm_rf(project_path) if Dir.exist?(project_path)

project = Xcodeproj::Project.new(project_path)
target = project.new_target(:application, 'Shengji', :ios, '16.0')

app_group = project.main_group.new_group('Shengji', 'Shengji')
source_files = Dir.glob(File.join(root, 'Shengji', '**', '*.swift')).sort
source_files.each do |path|
  relative = path.sub(File.join(root, 'Shengji') + '/', '')
  current_group = app_group
  parts = relative.split('/')
  parts[0...-1].each do |part|
    current_group = current_group.groups.find { |group| group.display_name == part } || current_group.new_group(part, part)
  end
  file = current_group.new_file(parts.last)
  target.source_build_phase.add_file_reference(file)
end

assets = app_group.new_file('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets)
privacy = app_group.new_file('PrivacyInfo.xcprivacy')
target.resources_build_phase.add_file_reference(privacy)
app_group.new_file('Info.plist')

target.frameworks_build_phase.files
  .select { |build_file| build_file.file_ref&.path&.include?('Foundation.framework') }
  .each { |build_file| build_file.remove_from_project }

frameworks_group = project.frameworks_group
%w[AVFoundation.framework Speech.framework].each do |framework_name|
  reference = frameworks_group.new_file("System/Library/Frameworks/#{framework_name}")
  reference.source_tree = 'SDKROOT'
  target.frameworks_build_phase.add_file_reference(reference)
end

settings = {
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.local.shengji',
  'PRODUCT_NAME' => 'Shengji',
  'INFOPLIST_FILE' => 'Shengji/Info.plist',
  'IPHONEOS_DEPLOYMENT_TARGET' => '16.0',
  'TARGETED_DEVICE_FAMILY' => '1',
  'SWIFT_VERSION' => '5.0',
  'MARKETING_VERSION' => '0.1.0',
  'CURRENT_PROJECT_VERSION' => '1',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'CODE_SIGN_STYLE' => 'Automatic',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'SUPPORTED_PLATFORMS' => 'iphoneos iphonesimulator',
  'SUPPORTS_MACCATALYST' => 'NO',
  'ENABLE_PREVIEWS' => 'YES',
  'SWIFT_EMIT_LOC_STRINGS' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
  'INFOPLIST_KEY_LSApplicationCategoryType' => 'public.app-category.productivity'
}

project.build_configurations.each do |configuration|
  configuration.build_settings.merge!(settings)
end
target.build_configurations.each do |configuration|
  configuration.build_settings.merge!(settings)
  configuration.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  configuration.build_settings['CODE_SIGN_IDENTITY[sdk=iphonesimulator*]'] = ''
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(project_path, 'Shengji', true)
puts "Generated #{project_path}"
