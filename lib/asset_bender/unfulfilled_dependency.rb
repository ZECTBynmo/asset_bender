# Represents a specific version of a dependency that may or may not have
# been downloaded locally yet
module AssetBender
  class UnfulfilledDependency
    include LoggerUtils

    attr_reader :name, :version

    def initialize(name, resolved_version)
      @name = name
      @version = resolved_version
      raise AssetBender::VersionError.new "Dependencies (even unfulfilled ones) should have fixed version numbers (version = #{@version})" if @version.is_wildcard?
    end

    def to_s
      "#{@name} #{@version}"
    end
  end
end
