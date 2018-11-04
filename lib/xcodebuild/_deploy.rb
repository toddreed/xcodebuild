# This script is exported by Xcodebuild.make_deploy_script to the directory build/Artifacts/Packages to allow a build
# server to easily upload IPAs to TestFlight. The build server should run:
#
# ruby deploy.rb [packages_dir]
#
# If packages_dir is omitted, it's assumed to be the parent directory of deploy.rb

require 'pathname'

# @return [String] the value of the environment variable DEVELOPER_DIR if set, otherwise the path returned by
# xcode-select -p.
def xcode_path
  ENV.fetch('DEVELOPER_DIR', `xcode-select -p`.chomp)
end

def transporter_path
  search_root = File.expand_path(File.join(xcode_path, '..'))
  path = %x{find #{search_root} -name iTMSTransporter}.chomp
  return path if File.exist?(path)
  raise "iTMSTransporter not found."
end

packages_path = if ARGV.length == 0
                  Pathname.new(File.dirname(__FILE__))
                else
                  Pathname.new(ARGV[0])
                end

transporter = transporter_path

Pathname.glob(File.join(packages_path, '*.itmsp')).each do |package|
  args = [transporter, '-m', 'upload', '-f', package.to_s, '-u', '@env:APP_STORE_CONNECT_USER', '-p', '@env:APP_STORE_CONNECT_PASSWORD', '-v', 'detailed']
  unless system(*args)
    raise "#{args[0]} return exit status code #{$?.exitstatus}"
  end
end