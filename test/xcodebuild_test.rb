require "test_helper"
require 'xcodebuild/utils'

class XcodeBuildTest < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::XcodeBuild::VERSION
  end

end
