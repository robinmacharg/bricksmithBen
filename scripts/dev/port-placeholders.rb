# Register an empty X.swift next to each named class's X.m, in the same group, in the Bricksmith Sources phase
# (L99: parallel ports never edit project.pbxproj). Idempotent (L12).
# Usage (from trunk/Bricksmith): bundle exec ruby ../../scripts/dev/port-placeholders.rb PHASE Class1 Class2 ...
require 'xcodeproj'
phase = ARGV.shift or abort 'usage: port-placeholders.rb PHASE Class...'
names = ARGV
abort 'no class names' if names.empty?
proj = Xcodeproj::Project.open('Bricksmith.xcodeproj')
target = proj.targets.find { |t| t.name == 'Bricksmith' } or abort 'no target'
names.each do |n|
  m = proj.files.find { |f| f.display_name == "#{n}.m" } or abort "no #{n}.m"
  group = m.parent
  swift = File.join(File.dirname(m.real_path.to_s), "#{n}.swift")
  File.write(swift, "//\n//  #{n}.swift\n//  Bricksmith\n//\n//  #{phase} placeholder: the Swift port of #{n} lands here.\n//\n") unless File.exist?(swift)
  ref = group.files.find { |f| f.display_name == "#{n}.swift" } || group.new_reference("#{n}.swift")
  target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
  abort "missing #{ref.real_path}" unless File.exist?(ref.real_path.to_s)
  puts "#{n}.swift -> #{ref.real_path.relative_path_from(Pathname.pwd)}"
end
proj.save
