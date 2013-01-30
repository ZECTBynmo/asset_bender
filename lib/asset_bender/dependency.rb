module AssetBender
  class Dependency < Project

    def initialize(config)
      super
      raise "Dependencies should have fixed version numbers (version = #{@version}" if @version.is_wildcard
    end

  end
end