# Remove emptied (ported) ObjC files from the Bricksmith project, delete them from disk, and drop their
# bridging-header imports. Usage (from trunk/Bricksmith): bundle exec ruby ../../scripts/dev/port-remove-stubs.rb X.h X.m ...
# Refuses a file that isn't a one-line "Ported to ..." stub. Idempotent (L12).
require 'xcodeproj'
names = ARGV
proj = Xcodeproj::Project.open('Bricksmith.xcodeproj')
bridge = 'Source/Swift/Bricksmith-Bridging-Header.h'
names.each do |n|
  ref = proj.files.find { |f| f.display_name == n }
  unless ref then puts "#{n}: not in project (already removed?)"; next end
  path = ref.real_path.to_s
  if File.exist?(path)
    body = File.read(path).strip
    abort "#{n}: not a ported stub: #{body[0,80].inspect}" unless body.start_with?('// Ported to') && body.lines.size == 1
  end
  proj.targets.each { |t| t.build_phases.each { |ph| ph.files.select { |bf| bf.file_ref == ref }.each { |bf| ph.remove_build_file(bf) } } }
  ref.remove_from_project
  File.delete(path) if File.exist?(path)
  if n.end_with?('.h')
    b = File.read(bridge); nb = b.gsub(/^#import "#{Regexp.escape(n)}"\n/, '')
    File.write(bridge, nb) if nb != b
  end
  puts "#{n}: removed"
end
proj.save
