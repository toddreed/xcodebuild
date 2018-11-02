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

    def initialize(path, app_id, platform)
      @path = path # a Pathname
      @app_id = app_id
      @platform = platform
    end

    def md5
      md5 = Digest::MD5.new
      @path.open('rb') do |f|
        f.each_chunk(1024) {|chunk| md5.update(chunk)}
      end
      md5.hexdigest
    end

    def bytes
      @path.size
    end

    def xml_meta_data
      %Q(<?xml version="1.0" encoding="UTF-8"?>
<package version="software5.3" xmlns="http://apple.com/itunes/importer">
    <software_assets apple_id="#{@app_id}" app_platform="#{@platform}">
        <asset type="bundle">
            <data_file>
                <file_name>#{@path.basename.to_s}</file_name>
                <checksum type="md5">#{self.md5}</checksum>
                <size>#{self.bytes}</size>
            </data_file>
        </asset>
    </software_assets>
</package>)
    end

    def upload(username, password)
      export_plist = Tempfile.new(['export', '.plist'])
      begin
        Dir.mktmpdir do |dir|
          package_path = Pathname.new(dir) / 'Package.itmsp'
          package_path.mkpath
          FileUtils.cp @path, package_path
          (package_path / 'metadata.xml').open('w') do |f|
            f.write(self.xml_meta_data)
          end
          XcodeBuild.run(XcodeBuild.transporter_path, '-m', 'upload', '-f', dir, '-u', username, '-p', password, '-v', 'detailed')
        end
      ensure
        export_plist.close
        export_plist.unlink
      end
    end

  end
end
