require 'digest'
require 'tempfile'
require 'fileutils'
require 'xcodebuild/run'

class File
  def each_chunk(chunk_size = 1024)
    yield read(chunk_size) until eof?
  end
end

module XcodeBuild

  class Package

    def initialize(ipa_path, app_id, platform)
      @ipa_path = ipa_path # a Pathname
      # iTMSTransporter does not allow spaces in the IPA filename
      @ipa_safe_filename = ipa_path.basename.to_s.sub(/ /, '-')
      @app_id = app_id
      @platform = platform
    end

    def md5
      md5 = Digest::MD5.new
      @ipa_path.open('rb') do |f|
        f.each_chunk(1024) {|chunk| md5.update(chunk)}
      end
      md5.hexdigest
    end

    def bytes
      @ipa_path.size
    end

    def xml_meta_data
      %Q(<?xml version="1.0" encoding="UTF-8"?>
<package version="software5.3" xmlns="http://apple.com/itunes/importer">
    <software_assets apple_id="#{@app_id}" app_platform="#{@platform}">
        <asset type="bundle">
            <data_file>
                <file_name>#{@ipa_safe_filename}</file_name>
                <checksum type="md5">#{self.md5}</checksum>
                <size>#{self.bytes}</size>
            </data_file>
        </asset>
    </software_assets>
</package>)
    end

    # Creates the directory that can be passed to iTMSTransporter via the `-f` command line option. This directory
    # contains a copy of the .ipa file and `metadata.xml` file providing metadata about the .ipa file.
    #
    # @param package_path [Pathname] The path location where the package is created. This directory typically has a `
    # .itmsp` extension.
    def make_itmsp(package_path)
      package_path.mkpath
      FileUtils.cp(@ipa_path, package_path/@ipa_safe_filename)
      metadata_xml_path = package_path / 'metadata.xml'
      metadata_xml_path.write(self.xml_meta_data)
    end

  end
end
