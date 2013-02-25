module AssetBender
  class Dependency < AbstractFilesystemProject

    def initialize(config, path)
      super
      raise AssetBender::VersionError.new "Dependencies should have fixed version numbers (version = #{@version}" if @version.is_wildcard?
    end

  end
end