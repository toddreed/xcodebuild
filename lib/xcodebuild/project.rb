require 'YAML'
require 'pathname'

class Hash

  def symbolize_keys
    self.keys.each do |key|
      self[key.to_sym] = self.delete(key)
    end
    self
  end

end

module XcodeBuild

  class BuildSettings

    def initialize(sdk: 'iphoneos',
                   code_signing_identity: 'iPhone Distribution',
                   certificate: nil,
                   code_sign_style: 'Manual')
      @sdk = sdk
      @code_signing_identity = code_signing_identity
      @certificate = certificate
      @code_sign_style = code_sign_style
      @parent = nil
    end

    attr_writer :parent, :sdk, :code_signing_identity, :certificate, :code_sign_style

    def sdk
      @sdk || @parent&.sdk
    end

    def code_signing_identity
      @code_signing_identity || @parent&.code_signing_identity
    end

    def certificate
      @certificate || @parent&.certificate
    end

    def code_sign_style
      @code_sign_style || @parent&.code_sign_style
    end

  end

  class BuildProject < BuildSettings
    attr_reader :workspace, :project, :builds, :tests, :build_dir, :certificates_dir, :provisioning_profiles_dir
    attr_reader :artifacts_path, :archives_path, :exports_path, :packages_path


    def initialize(sdk: 'iphoneos',
                   code_signing_identity: 'iPhone Distribution',
                   certificate: nil,
                   code_sign_style: 'Manual',
                   workspace: nil,
                   project: nil,
                   build_dir: './build',
                   certificates_dir: './certificates',
                   provisioning_profiles_dir: './profiles')
      super(sdk: sdk, code_signing_identity: code_signing_identity, certificate: certificate, code_sign_style: code_sign_style)
      @workspace = workspace
      @project = project
      @builds = []
      @tests = []
      @build_dir = File.absolute_path(build_dir)
      @artifacts_path = Pathname.new(build_dir) / 'Artifacts'
      @archives_path = @artifacts_path / 'Archives'
      @exports_path = @artifacts_path / 'Exports'
      @packages_path = @artifacts_path / 'Packages'
      @certificates_dir = File.absolute_path(certificates_dir)
      @provisioning_profiles_dir = File.absolute_path(provisioning_profiles_dir)
    end

    def self.load(build_file)
      puts "Using #{build_file}"

      config_hash = YAML.load_file(build_file).symbolize_keys
      project_hash = config_hash.clone
      project_hash.delete(:builds)
      project_hash.delete(:tests)

      project = BuildProject.new(**project_hash.symbolize_keys)

      config_hash.fetch(:builds, []).each do |build_hash|
        build = Build.new(**build_hash.symbolize_keys)
        project.add_build(build)
      end

      config_hash.fetch(:tests, []).each do |test_hash|
        test = Test.new(**test_hash.symbolize_keys)
        project.add_test(test)
      end

      project

    end

    def add_test(test)
      test.project = self
      test.parent = self
      @tests << test
    end

    def add_build(build)
      build.project = self
      build.parent = self
      @builds << build
    end

  end

  class Build < BuildSettings
    attr_reader :scheme, :configuration, :provisioning_profile, :export_options_plist, :app_id
    attr_accessor :project

    def initialize(sdk: nil,
                   code_signing_identity: nil,
                   certificate: nil,
                   code_sign_style: nil ,
                   scheme:,
                   provisioning_profile:,
                   configuration: 'Release',
                   export_options_plist: 'ExportOptions.plist',
                   app_id: nil)
      super(sdk: sdk, code_signing_identity: code_signing_identity, certificate: certificate, code_sign_style: code_sign_style)
      @scheme = scheme
      @provisioning_profile = provisioning_profile
      @configuration = configuration
      @export_options_plist = export_options_plist
      @app_id = app_id
      @project = nil
    end

    def name
      name = "#{@scheme}"

      if @configuration
        name << "-#{@configuration}"
      end
      if @provisioning_profile
        name << "-#{@provisioning_profile}"
      end

      name.gsub(/\s/, '_')
    end

    # @return [Pathname] The location of the archive (`.xcarchive`).
    def archive_path
      @project.archives_path / "#{self.name}.xcarchive"
    end

    # @return [Pathname] The location of the package (`.itmsp`) used by iTMSTransporter.
    def package_path
      @project.packages_path / "#{self.name}.itmsp"
    end

    # @return [Pathname] The location of the exported `.ipa` file.
    def ipa_path
      self.export_path / "#{@scheme}.ipa"
    end

    # @return [Pathname] The location of the directory containing the output of xcodebuild -exportArchive.
    def export_path
      @project.exports_path / self.name
    end

  end

  class Test < BuildSettings
    attr_reader :scheme, :destinations, :test_plan
    attr_accessor :project

    def initialize(sdk: 'iphoneos',
                   code_signing_identity: nil,
                   certificate: nil,
                   code_sign_style: nil,
                   scheme:,
                   destinations: [],
                   test_plan: nil)
      super(sdk: sdk, code_signing_identity: code_signing_identity, certificate: certificate, code_sign_style: code_sign_style)
      @scheme = scheme
      @destinations = destinations
      @project = nil
      @test_plan = test_plan
    end
  end

end
