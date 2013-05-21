module AssetBender
  class DependencyError < AssetBender::Error; end

  class Dependency < AbstractFilesystemProject

    def initialize(config, path)
      super
      raise AssetBender::VersionError.new "Dependencies should have fixed version numbers (version = #{@version}" if @version.is_wildcard?
    end

    def is_dependency
      true
    end

    def is_project
      false
    end

    def dependency_config
      fixed_dependencies = @config[:fixed_dependencies]

      if @config[:dependencies] and not @config[:dependencies].empty? and not fixed_dependencies
        raise AssetBender::DependencyError, "#{self} is missing fixed_dependencies, even though it has normal dependencies. Was this not built correctly?"
      end
    end

  end
end