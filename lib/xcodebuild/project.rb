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

    def archive_path
      self.export_path.sub_ext('.xcarchive')
    end

    def ipa_path
      self.export_path / "#{@scheme}.ipa"
    end

    def export_path
      Pathname.new("#{@project.build_dir}/Artifacts/#{self.name}")
    end

  end

  class Test < BuildSettings
    attr_reader :scheme, :destinations
    attr_accessor :project

    def initialize(sdk: SDK::IPHONESIMULATOR,
                   code_signing_identity: nil,
                   certificate: nil,
                   code_sign_style: nil,
                   scheme:,
                   destinations: [])
      super(sdk: sdk, code_signing_identity: code_signing_identity, certificate: certificate, code_sign_style: code_sign_style)
      @scheme = scheme
      @destinations = destinations
      @project = nil
    end
  end

end
