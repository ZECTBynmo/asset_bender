module AssetBender
  class Dependency < FilesystemProject

    def initialize(config)
      super
      raise AssetBender::VersionError.new "Dependencies should have fixed version numbers (version = #{@version}" if @version.is_wildcard
    end

  end
end