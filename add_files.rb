require 'xcodeproj'
project_path = 'Clipboard.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

['Clipboard/SettingsWindowController.swift', 'Clipboard/SettingsView.swift'].each do |file_path|
  next if target.source_build_phase.files_references.find { |f| f.path == file_path.split('/').last }
  file_ref = project.main_group.find_subpath(File.dirname(file_path), true).new_reference(File.basename(file_path))
  target.add_file_references([file_ref])
end

project.save
