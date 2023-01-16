# xcodebuild

Xcodebuild is a Ruby gem that implements a [rake](https://github.com/ruby/rake) task library for building Xcode projects.

**Warning**: this project is unsupported, not under active development, and not intended for a general audience. I’m not a Ruby developer, so this project contains bad Ruby code, and there are probably better projects out there that accomplish similar things (for example, [fastlane](https://fastlane.tools) and [xcbuild](https://github.com/facebook/xcbuild)).

## Usage

### Prerequisites

- Ruby. Ruby comes preinstalled on macOS, but it’s recommended to use [rbenv](https://github.com/rbenv/rbenv) or [RVM](https://rvm.io) to manage Ruby versions.
- [Bundler](https://bundler.io). Once you have your preferred Ruby interpreter setup, run  `gem install bundler`.

## Setup

To use Xcodebuild in a project:

1. Create a Gemfile. This should contain something like this:

   ```ruby
   ruby '2.4.2'
   source 'https://rubygems.org'
   
   git_source(:github) { |repo_name| "git@github.com:#{repo_name}.git" }
   
   gem 'xcodebuild', :github => 'toddreed/xcodebuild'
   gem 'cocoapods'
   ```

2. Run `bundle install` to install the dependencies.

3. Add `Gemfile` and `Gemfile.lock` to your project’s Git repository:

   ```sh
   git add Gemfile Gemfile.lock
   ```

4. Create a Rakefile; this could be as simple as:

   ```ruby
   require 'rake'
   require 'xcodebuild'
   
   project = XcodeBuild::BuildProject.load('build.yml)
   XcodeBuild::Tasks.new(project)
   ```

5. Create a YAML file that describes your build configuration (see § “Configuring Build Projects” below for more information):

   ```yaml
   workspace: Foo.xcworkspace
   certificate: Distribution.p12
   
   builds:
     - scheme: Foo
       provisioning_profile: Foo App Store
       export_options_plist: ExportOptions.plist
       app_id: 999999999
   ```

6. Define necessary environment variables. See below for details.

7. Run, for example, `bundle exec rake package`. To see a list of tasks, run `bundle exec rake -T`.

### Usage

The typical usage would be:

```sh
bundle exec rake deploy tag
```

If the building and deployment steps are separated, you could:

```sh
bundle exec rake package tag
```

and then later:

```
bundle exec rake deploy_only
```

### Environment Variables

| Variable                         | Description                                                  | Default                                                      |
| -------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `BUILD_NUMBER`                   | The build number passed to `xcodebuild` (the Xcode command line tool, not this library) and assigned to the `CURRENT_PROJECT_VERSION` build setting of your Xcode project. This assumes that in your `Info.plist` file you assign the Bundle version property (`CFBundleVersion`) to `$(CURRENT_PROJECT_VERSION)`. | If `BUILD_NUMBER` is not set then a build number may be inferred. See the section below for how build numbers are inferred. |
| `INFERRED_BUILD_NUMBER_STRATEGY` | If `BUILD_NUMBER` is not set, this indicates what strategy to use to infer the build number. See the § “Inferred Build Numbers” below. |                                                              |
| `DEVELOPER_DIR`                  | Controls the version of Xcode tools used.                    | The output from running `xcode-select -p`.                   |
| `APP_STORE_CONNECT_USER`         | The Apple ID for an App Store Connect account with the Developer role used to upload builds. This is only used for the `deploy` task that uploads the `.ipa` file to TestFlight. |                                                              |
| `APP_STORE_CONNECT_PASSWORD`     | The password for the above Apple ID account.                 |                                                              |
| `CERTIFICATE_PASSWORD`           | The password used for `.p12` certificates. Currently it is assumed that all certificates have the same password. This is only used when running in a CI environment; otherwise, it is assumed that the necessary certificates (and provisioning profiles) are on the developer’s machine. |                                                              |

## Inferred Build Numbers

If the `BUILD_NUMBER` environment variable is not set, then a build number can be inferred according to the strategy set by the `INFERRED_BUILD_NUMBER_STRATEGY` environment variable. Currently there is only one strategy for inferring build number: `github_build_tag`.

If `INFERRED_BUILD_NUMBER_STRATEGY` is not set, then the inferred build number will be `0`.

### GitHub and Build Tags

| Environment Variable             | Value or Description                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `INFERRED_BUILD_NUMBER_STRATEGY` | `github_build_tag`                                           |
| `GITHUB_TOKEN`                   | The GitHub token that provides authorization to the GitHub repository. If using GitHub Actions, a token can be obtained from the `${{ secrets.GITHUB_TOKEN }}` expression in the workflow. |
| `GITHUB_REPOSITORY`              | The name of the GitHub repository. This environment variable is a default provided by GitHub Actions. |

A build tag is assumed to have the form `build/N` where `N` is the build number. For example, if the most recent build tag is `build/42`, then the implied build number is 43 (`N`+1). If no tag of the form `build/N` exists, then the build number will be `1`. 

The `tag` Rake task can be used to generate a new build tag.

This strategy uses the GitHub REST API to query and set build tags.

## Build Projects

A *build project* is a description of what you want to build. It specifies the Xcode project or workspace, the scheme and configuration to use, and other build settings and metadata needed to create an `.xcarchive` or `.ipa` file. There are two ways to specifying your build project: with a YAML file, or with Ruby code in your Rakefile.

A build project has the following model:

![build-project-model](README.assets/build-project-model.svg)

### Configuring Build Projects

A build project can be specified with a YAML file. The following properties can be set:

| Property                    | Type    | Default          | Required?                                           | Description                                                  |
| --------------------------- | ------- |------------------| --------------------------------------------------- | ------------------------------------------------------------ |
| `sdk`                       | string  | `iphoneos`       | Yes                                                 | One of: `iphoneos`, `iphonesimulator`, `macosx`, `appletvos`, etc. The SDK value passed to `xcodebuild` via the `-sdk` option. |
| `code_signing_identity`     | string  | nil              |                                                     | Sets the `CODE_SIGN_IDENTITY` Xcode build setting.           |
| `certificate`               | string  | nil              |                                                     | The filename of the certificate file used to code sign the build. This file should be located in the directory specified by `certificates_dir`. The certificate will be added to a temporary Keychain. |
| `code_sign_style`           | string  | nil              |                                                     | Sets the `CODE_SIGN_STYLE` Xcode build setting.              |
| `workspace`                 | string  | nil              | Only one of `workspace` or `project` should be set. | The Xcode workspace file to use with `xcodebuild`.           |
| `project`                   | string  | nil              | Only one of `workspace` or `project` should be set. | The Xcode project path to use with `xcodebuild`. Only one of `workspace` or `project` should be set. |
| `build_dir`                 | string  | `./build`        |                                                     | The directory path for the build output.                     |
| `certificates_dir`          | string  | `./certificates` |                                                     | The directory where certificate files are located.           |
| `provisioning_profiles_dir` | string  | `./profiles`     |                                                     | The directory where provisioning profiles are located. Provisioning profiles in this directory will be copied to `~/Library/MobileDevice/Provisioning Profiles` during the build and removed when the build completes. |
| `builds`                    | [Build] | []               |                                                     | An array of Build objects. `xcodebuild` is run for each Build object. |
| `tests`                     | [Test]  | []               |                                                     | Any array of Test objects. `xcodebuild` is run for each Test object. |

#### Build Objects

Build objects can have the following properties:

| Property                | Type   | Default               | Required? | Description                                                  |
| ----------------------- | ------ | --------------------- | --------- | ------------------------------------------------------------ |
| `sdk`                   | string | Inherited             | Yes       | See above.                                                   |
| `code_signing_identity` | string | Inherited             |           | See above.                                                   |
| `certificate`           | string | Inherited             |           | See above.                                                   |
| `code_sign_style`       | string | Inherited             |           | See above.                                                   |
| `scheme`                | string |                       | Yes       | The scheme value passed to `xcodebuild` via the `-scheme` option. |
| `provisioning_profile`  | string |                       |           | The name of the provisioning profile. Sets the `PROVISIONING_PROFILE_SPECIFIER` Xcode build setting. (This is not the filename of the provisioning profile, but the name of the provisioning profile specified in the file itself.) |
| `configuration`         | string | `Release`             |           | The configuration value passed to `xcodebuild` via the `-configuration` option. |
| `export_options_plist`  | string | `ExportOptions.plist` | Yes       | The path to an export options file. This is passed to `xcodebuild` (via the `--exportOptionsPlist` option) when exporting an archive. |
| `app_id`                | string |                       | Yes       | The app’s App ID (found in App Store Connect).               |

#### Test Objects

Test objects can have the following properties:

| Property                | Type     | Default   | Required? | Description                                                  |
| ----------------------- | -------- | --------- | --------- | ------------------------------------------------------------ |
| `sdk`                   | string   | Inherited | Yes       | See above.                                                   |
| `code_signing_identity` | string   | Inherited |           | See above.                                                   |
| `certificate`           | string   | Inherited |           | See above.                                                   |
| `code_sign_style`       | string   | Inherited |           | See above.                                                   |
| `scheme`                | string   |           |           | The scheme value passed to `xcodebuild` via the `-scheme` option. |
| `destinations`          | [string] |           | Yes       | The destinations for running the tests. Each value is passed to `xcodebuild` via the `-destination` option. |
| `test_plan`             | string   | nil       |           | The test plan passed to `xcodebuild` via the `-testPlan` option. |

## Tasks

The tasks and their dependencies:

![tasks](README.assets/tasks.svg)

The `package` tasks creates an `.xcarchive`, and the `deploy` tasks uploads to App Store Connect (TestFlight).

The `install_certificates` and `install_provisioning_profiles` tasks are no-ops when performed on a developer’s machine. This is determined by the existence of any environment variables that indicate that rake is running in a CI environment (e.g. `CI`, `TRAVIS`, `GITHUB_ACTIONS`, or `TF_BUILD`). On a developer’s machine, it is assumed that the necessary certificates are in the login keychain and the requisite provisioning profiles are present in `~/Library/MobileDevice/Provisioning Profiles`.

## Debugging with RubyMine

To debug the Rake library a suitable test project is needed to run the Rake tasks on. The `Gemfile` for the test project needs to reference the source path of this project; for example:

```ruby
# Normally this would be used…
# gem 'xcodebuild', :git => 'https://github.com/toddreed/xcodebuild.git'
# To debug we need this…
gem 'xcodebuild', :path => '/Users/todd/Organization/Reaction/Source/xcodebuild'
```

Don’t forget to run `bundle install` after editing the `Gemfile`.

In RubyMine, your Run Configuration should look something like this:

![RubyMine-Run-Configuration-Configuration](README.assets/RubyMine-Run-Configuration-Configuration.png)

![RubyMine-Run-Configuration-Bundler](README.assets/RubyMine-Run-Configuration-Bundler.png)

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

