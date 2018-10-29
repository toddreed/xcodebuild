require 'shellwords'
require 'date'
require 'xcodebuild/run'

module XcodeBuild

  PID = $$

  def self.is_ci_build
    ENV['CI'] == 'true' || ENV['TRAVIS'] == 'true' || ENV['TF_BUILD'] == 'True'
  end

  def self.is_dev_build
    !is_ci_build
  end

  def self.install_certificate(certificate)
    build_keychain = "Build-#{PID}.keychain"

    # Get original list of keychains so we can restore these when we're done building
    original_keychains = %x{security list-keychains -d user}.shellsplit
    certificate_password = ENV.fetch('CERTIFICATE_PASSWORD', '')

    run('security', 'create-keychain', '-p', '', build_keychain)
    run('security', 'unlock-keychain', '-p', '', build_keychain)
    run('security', 'default-keychain', '-d', 'user', '-s', build_keychain)
    run('security', 'list-keychains', '-s', build_keychain, '/Library/Keychains/System.keychain')

    at_exit do
      run('security', 'delete-keychain', build_keychain)
      run(*%w(security list-keychains -s).concat(original_keychains))
      run(*%w(security default-keychain -s login.keychain))
    end

    #run('security', 'import', certificate, '-k', build_keychain, '-t', 'cert', '-f', 'pkcs12',
    #    '-P', certificate_password, '-A')

    run('security', 'import', certificate, '-k', build_keychain, '-t', 'cert', '-f', 'pkcs12',
        '-T', '/usr/bin/codesign', '-T', '/usr/bin/xcodebuild', '-P', certificate_password)
    run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-s', '-k', '', build_keychain)
    run('security', 'set-keychain-settings', '-lut', '3600', build_keychain)

  end

  def self.install_provisioning_profile(profile)
    profiles_dir = File.expand_path '~/Library/MobileDevice/Provisioning Profiles'
    unless File.exists?(profiles_dir)
      puts "Creating #{profiles_dir}."
      FileUtils::makedirs(profiles_dir)
    end
    puts "Copying #{profile} to #{profiles_dir}"
    profile_copy = File.join(profiles_dir, File.basename(profile))
    FileUtils::copy_file(profile, profile_copy)

    at_exit do
      puts "Removing provisioning profile #{profile_copy}"
      FileUtils.remove(profile_copy)
    end
  end

  def self.default_build_number
    date = Date.today
    "#{date.year}.#{date.yday}.0"
  end

  def self.build_number
    ENV.fetch('BUILD_NUMBER', default_build_number)
  end

  # Runs xcodebuild. The Xcode version is based on the DEVELOPER_DIR environment variable, if it exists. Otherwise,
  # is uses the projects 'xcode_app' setting.
  def self.xcodebuild(scheme, configuration, args, action, project, build_settings)
    developer_dir = ENV.fetch('DEVELOPER_DIR', "/Applications/Xcode.app/Contents/Developer")
    env = {'DEVELOPER_DIR' => developer_dir}

    xcode_args = Array.new
    xcode_args << 'xcodebuild'
    if project.project
      xcode_args << '-project' << project.project
    else
      xcode_args << '-workspace' << project.workspace
    end

    xcode_args << '-scheme' << scheme

    if configuration
      xcode_args << '-configuration' << configuration
    end

    xcode_args.concat(args)
    xcode_args << action

    xcode_args << "OBJROOT=#{project.build_dir}/Intermediates"
    xcode_args << "SHARED_PRECOMPS_DIR=#{project.build_dir}/PrecompiledHeaders"
    xcode_args << "BUILD_NUMBER=#{build_number}"
    xcode_args.concat(build_settings)

    if action == 'test'
      test_log = "#{project.build_dir}/#{scheme}-test.log"
      run(env, *xcode_args, :out => test_log)
      process_test_log(test_log, scheme, project.build_dir)
    else
      run(env, *xcode_args)
    end
  end

  # Runs xcodebuild archive with a Build object.
  def self.archive(build)
    args = Array.new
    args << '-archivePath' << "#{build.project.build_dir}/#{build.name}.xcarchive"
    args << '-sdk' << build.sdk

    build_settings = Array.new
    if build.certificate && !is_dev_build
      build_keychain = "Build-#{PID}.keychain"
      build_settings << "OTHER_CODE_SIGN_FLAGS=--keychain #{build_keychain}"
    end

    if build.code_sign_style
      build_settings << "CODE_SIGN_STYLE=#{build.code_sign_style}"
    end
    if build.code_signing_identity
      build_settings << "CODE_SIGN_IDENTITY=#{build.code_signing_identity}"
    end
    if build.provisioning_profile
      build_settings << "PROVISIONING_PROFILE_SPECIFIER=#{build.provisioning_profile}"
    end

    xcodebuild(build.scheme, build.configuration, args, 'archive', build.project, build_settings)
  end

  # Runs xcodebuild test with a Test object.
  def self.test(test)
    args = Array.new
    args << '-sdk' << test.sdk
    args << '-destination' << test.destinations.join(',')
    args << '-sdk' << test.sdk

    xcodebuild(test.scheme, test.configuration, args, 'test', test.project, [])
  end

  def self.export_archive(build)
    developer_dir = ENV.fetch('DEVELOPER_DIR', "/Applications/Xcode.app/Contents/Developer")
    env = {'DEVELOPER_DIR' => developer_dir}

    xcode_args = Array.new
    xcode_args << 'xcodebuild' << '-exportArchive'
    xcode_args << '-exportOptionsPlist' << build.export_options_plist
    xcode_args << '-archivePath' << "#{build.project.build_dir}/#{build.name}.xcarchive"
    xcode_args << '-exportPath' << "#{build.project.build_dir}/#{build.name}"

    run(env, *xcode_args)
  end

  def self.fix_test_output(test_log)
    content = File.read(test_log)
    content.sub!("** TEST SUCCEEDED **\n\n", '')
    File.open(test_log, 'w') {|file| file.puts content}
  end

  def self.process_test_log(test_log, scheme, build_dir)
    fix_test_output(test_log)
    args = %w(xcpretty --report junit --output)
    args << "#{build_dir}/#{scheme}-junit.xml"
    run(*args, :in => test_log)
  end

end