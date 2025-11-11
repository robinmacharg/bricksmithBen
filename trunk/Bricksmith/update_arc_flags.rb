#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

# Files to enable or disable ARC
ARC_SAFE_LIST = 'arc_safe_files.txt'
NON_ARC_LIST  = 'non_arc_files.txt'

# Load the Xcode project
project_path = Dir.glob('*.xcodeproj').first
abort "❌ No .xcodeproj found!" unless project_path

project = Xcodeproj::Project.open(project_path)
puts "📁 Opened project: #{project_path}"

def normalize_path(path)
  path.sub(%r{^\./}, '') # remove leading ./
end

# def add_flag_to_files(project, file_list, flag)
#   return unless File.exist?(file_list)
#   File.readlines(file_list).each do |line|
#     file_path = normalize_path(line.strip)
#     next if file_path.empty?

#     file_ref = project.files.find { |f| normalize_path(f.path || '') == file_path }
#     unless file_ref
#       puts "⚠️  File not found in project: #{file_path}"
#       next
#     end

#     # Add or update compiler_flags
#     build_files = project.targets.flat_map(&:source_build_phase).flat_map(&:files).select { |bf| bf.file_ref == file_ref }
#     build_files.each do |bf|
#       bf.settings ||= {}
#       bf.settings['COMPILER_FLAGS'] = flag
#       puts "✅ Set #{flag} for #{file_path}"
#     end
#   end
# end

def add_flag_to_files(project, file_list, flag)
  return unless File.exist?(file_list)
  File.readlines(file_list).each do |line|
    file_path = File.expand_path(line.strip)
    next if file_path.empty?

    file_ref = project.files.find do |f|
      begin
        f.real_path && File.expand_path(f.real_path.to_s) == file_path
      rescue
        false
      end
    end

    unless file_ref
      puts "⚠️  File not found in project: #{file_path}"
      next
    end

    # Add or update compiler_flags
    build_files = project.targets.flat_map(&:source_build_phase).flat_map(&:files).select { |bf| bf.file_ref == file_ref }
    build_files.each do |bf|
      bf.settings ||= {}
      bf.settings['COMPILER_FLAGS'] = flag
      puts "✅ Set #{flag} for #{file_path}"
    end
  end
end


# Enable ARC for safe files
add_flag_to_files(project, ARC_SAFE_LIST, '-fobjc-arc')

# Disable ARC for legacy files
add_flag_to_files(project, NON_ARC_LIST, '-fno-objc-arc')

# Save project
project.save
puts "✅ Project updated and saved."
