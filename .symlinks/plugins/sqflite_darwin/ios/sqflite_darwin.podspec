require 'yaml'
require 'json'

pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))
library_version = pubspec['version']

if library_version.to_s.empty?
  raise "Missing version in pubspec.yaml"
end

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'sqflite_darwin'
  s.version          = library_version
  s.summary          = 'SQFlite iOS and macOS plugin.'
  s.description      = <<-DESC
SQFlite iOS and macOS plugin.
                       DESC
  s.homepage         = 'https://github.com/tekartik/sqflite'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tekartik' => 'alex@tekartik.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  # s.dependency 'sqlite3', '~> 3.49.2'
  s.platform = :ios, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end 