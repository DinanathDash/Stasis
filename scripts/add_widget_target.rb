require 'xcodeproj'

project_path = 'stasis.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target_name = 'StasisWidgets'

stasis_target = project.targets.find { |t| t.name == 'stasis' }
unless stasis_target
  raise "Could not find 'stasis' target in project!"
end

# Clean up any existing dependency references on stasis_target
stasis_target.dependencies.delete_if { |dep| dep.name == target_name || (dep.target && dep.target.name == target_name) }

# Clean up any existing references in Embed App Extensions phase
embed_phase = stasis_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' || p.dst_subfolder_spec == '13' }
if embed_phase
  embed_phase.files.delete_if { |bf| bf.file_ref && bf.file_ref.path && bf.file_ref.path.include?('StasisWidgets') }
end

existing_target = project.targets.find { |t| t.name == target_name }
if existing_target
  puts "Target #{target_name} already exists. Removing old target..."
  project.targets.delete(existing_target)
end

widget_target = project.new_target(
  :app_extension,
  target_name,
  :osx,
  '14.0',
  project.products_group,
  'com.dinanathdash.stasis.widgets'
)

widget_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['INFOPLIST_FILE'] = 'StasisWidgets/Info.plist'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.dinanathdash.stasis.widgets'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CODE_SIGN_IDENTITY'] = '-'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks @executable_path/../../../../Frameworks'
  stasis_config = stasis_target.build_configurations.find { |c| c.name == config.name } || stasis_target.build_configurations.first
  config.build_settings['CURRENT_PROJECT_VERSION'] = stasis_config.build_settings['CURRENT_PROJECT_VERSION'] || '58'
  config.build_settings['MARKETING_VERSION'] = stasis_config.build_settings['MARKETING_VERSION'] || '2.1.0'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'StasisWidgets/StasisWidgets.entitlements'
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  config.build_settings['OTHER_SWIFT_FLAGS'] = '$(inherited) -DWIDGET_EXTENSION'
end

source_files = [
  'StasisWidgets/StasisWidgetsBundle.swift',
  'StasisWidgets/StasisWidgetProvider.swift',
  'StasisWidgets/BatteryStatusWidget.swift',
  'StasisWidgets/PowerSankeyWidget.swift',
  'StasisWidgets/AppDelegateStub.swift',
  'Stasis/Models/WidgetStatusData.swift',
  'Stasis/Models/PercentageFormatter.swift',
  'Stasis/Models/PowerSource.swift',
  'Stasis/Models/BatteryMetrics.swift',
  'Stasis/Models/ChargingMode.swift',
  'Stasis/Models/PowerValueFormatter.swift',
  'Stasis/Views/PowerSankeyView.swift',
  'Stasis/Views/BatteryIndicatorView.swift',
  'Stasis/DefaultsKeys.swift',
  'Stasis/Intents/ToggleTopUpIntent.swift',
  'Stasis/Intents/ToggleSailingModeIntent.swift',
  'Stasis/Intents/SetChargeLimitIntent.swift',
  'Stasis/Intents/GetBatteryStatusIntent.swift'
]

source_files.each do |file_path|
  file_ref = project.files.find { |f| f.path == file_path } || project.new_file(file_path)
  widget_target.add_file_references([file_ref])
end

frameworks = ['WidgetKit', 'SwiftUI', 'AppIntents', 'AppKit', 'Foundation']
frameworks.each do |fw|
  widget_target.add_system_framework(fw)
end

defaults_dep = stasis_target.package_product_dependencies.find { |d| d.product_name == 'Defaults' }
if defaults_dep
  widget_target.package_product_dependencies << defaults_dep
else
  puts "Warning: Could not find Defaults package dependency on stasis target"
end

stasis_target.add_dependency(widget_target)

unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed App Extensions'
  embed_phase.dst_subfolder_spec = '13' # PlugIns folder
  stasis_target.build_phases << embed_phase
end

widget_product_ref = widget_target.product_reference
build_file = embed_phase.add_file_reference(widget_product_ref)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "Successfully added StasisWidgets app extension target to stasis.xcodeproj!"
