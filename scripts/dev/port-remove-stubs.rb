# Remove emptied (ported) ObjC files from the Bricksmith project, delete them from disk, and fix their importers.
# Usage (from trunk/Bricksmith): bundle exec ruby ../../scripts/dev/port-remove-stubs.rb X.h X.m ...
# Refuses a file that isn't a stub: a "// Ported to ..." line, optionally followed by "@class X;" lines
# (the forward-declaration stub that keeps importers compiling while streams run in parallel; P6a).
# For each removed X.h:
#   - the bridging header loses its import;
#   - every other .h under Source/ that imports it gets "@class X;" (the stub's @class lines) instead;
#   - every .m under Source/ drops the import (the P6a sweep gave them "Bricksmith-Swift.h").
# Idempotent (L12).
require 'xcodeproj'
names = ARGV
proj = Xcodeproj::Project.open('Bricksmith.xcodeproj')
bridge = 'Source/Swift/Bricksmith-Bridging-Header.h'
names.each do |n|
  ref = proj.files.find { |f| f.display_name == n }
  unless ref then puts "#{n}: not in project (already removed?)"; next end
  path = ref.real_path.to_s
  forward = []
  if File.exist?(path)
    lines = File.read(path).strip.lines.map(&:strip)
    ok = lines.first.to_s.start_with?('// Ported to') && lines.drop(1).all? { |l| l =~ /\A@class [A-Za-z_][A-Za-z0-9_, ]*;\z/ }
    abort "#{n}: not a ported stub: #{File.read(path)[0, 120].inspect}" unless ok
    forward = lines.drop(1)
  end
  proj.targets.each { |t| t.build_phases.each { |ph| ph.files.select { |bf| bf.file_ref == ref }.each { |bf| ph.remove_build_file(bf) } } }
  ref.remove_from_project
  File.delete(path) if File.exist?(path)
  if n.end_with?('.h')
    import = /^#import "#{Regexp.escape(n)}"[^\n]*\n/
    b = File.read(bridge); nb = b.gsub(import, '')
    File.write(bridge, nb) if nb != b
    Dir.glob('Source/**/*.{h,m}').each do |f|
      next if f == bridge
      s = File.read(f)
      next unless s =~ import
      s2 = f.end_with?('.h') ? s.gsub(import, forward.map { |l| l + "\n" }.join) : s.gsub(import, '')
      File.write(f, s2)
      puts "  #{f}: #{f.end_with?('.h') ? (forward.empty? ? 'import dropped' : 'import -> ' + forward.join(' ')) : 'import dropped'}"
    end
  end
  puts "#{n}: removed"
end
proj.save
