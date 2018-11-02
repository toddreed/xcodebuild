require 'rake'
require 'rake/tasklib'
require 'xcodebuild/utils'
require 'xcodebuild/package'

module XcodeBuild

  class Tasks < Rake::TaskLib

    def initialize(project)
      @project = project
      yield self if block_given?
      define
    end

    def define

      desc 'Removes all generated build files.'
      task :clean do
        FileUtils::rm_rf @project.build_dir
      end

      desc 'Install CocoaPods dependencies.'
      task :dependencies do
        if File.exists?('Podfile')
          XcodeBuild.run('pod', 'install')
        end
      end

      desc 'Install certificates'
      task :install_certificates do
        if XcodeBuild.is_dev_build
          puts 'Not installing certificates because this is a developer build.'
        else
          certificates = Set.new
          @project.builds.each do |build|
            if build.certificate
              certificates.add(File.join(@project.certificates_dir, build.certificate))
            end
          end

          certificates.each do |cert|
            XcodeBuild.install_certificate(cert)
          end
        end
      end

      desc 'Install provisioning profiles'
      task :install_provisioning_profiles do
        if XcodeBuild.is_dev_build
          puts 'Not installing certificates because this is a developer build.'
        else
          provisioning_profiles = Dir[File.join(@project.provisioning_profiles_dir, '*.mobileprovision')]
          provisioning_profiles.each do |provisioning_profile|
            XcodeBuild.install_provisioning_profile(provisioning_profile)
          end
        end
      end

      desc 'Build initialization.'
      task :initialize => [:install_certificates, :install_provisioning_profiles] do
        FileUtils::makedirs(@project.build_dir)
      end

      desc 'Runs unit tests.'
      task :test => [:initialize, :dependencies] do
        @project.tests.each do |test|
          XcodeBuild.test(test)
        end
      end

      desc 'Compiles the project.'
      task :compile => [:initialize, :dependencies] do
        @project.builds.each do |build|
          puts build
          XcodeBuild.archive(build)
        end
      end

      desc 'Creates an .ipa file'
      task :package => [:compile] do
        @project.builds.each do |build|
          XcodeBuild.export_archive(build)
        end
      end

      desc 'Prepares release notes from Git commit messages.'
      task :release_notes do
        release_notes = "(These release notes are automatically generated from Git commit messages.)\n\n"
        release_notes << `git log $(git describe --abbrev=0)..$(git rev-parse --abbrev-ref HEAD) --no-merges --format='- %s'`
        FileUtils.makedirs(@project.build_dir)
        File.open(File.join(@project.build_dir, 'Artifacts', RELEASE_NOTES), 'w') do |file|
          file.puts release_notes
        end
      end

      desc 'Deploys the package files.'
      task :deploy => [:package] do
        Rake::Task[:deploy_only].invoke
      end

      desc 'Deploys a previously built package.'
      task :deploy_only do
        @project.builds.each do |build|
          platform = case build.sdk
                     when 'iphoneos'
                       'ios'
                     when 'appletvos'
                       'appletvos'
                     when 'macosx'
                       'osx'
                     end
          package = XcodeBuild::Package.new(build.ipa_path, build.app_id, platform)
          package.upload('@env:APP_STORE_CONNECT_USER', '@env:APP_STORE_CONNECT_PASSWORD')
        end
      end

      task :default => [:compile]
    end
  end
end

