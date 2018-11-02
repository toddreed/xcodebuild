require "test_helper"
require 'xcodebuild/utils'

class XcodeBuildTest < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::XcodeBuild::VERSION
  end

  def test_transporter_path
    assert(XcodeBuild.transporter_path =~ %r{/Applications/Xcode.*.app/Contents/Applications/Application Loader.app/Contents/itms/bin/iTMSTransporter})
  end
end
