module AssetBender
  class DependencyError < AssetBender::Error; end

  class Dependency < AbstractFilesystemProject

    def initialize(config, path)
      super
      raise AssetBender::VersionError.new "Dependencies should have fixed version numbers (version = #{@version}" if @version.is_wildcard?

      dependencies_by_name.each do |dep_name, dep_version|
        raise AssetBender::VersionError.new "All of a dependency's dependencies should be fixed version numbers (version = #{dep_version}" if dep_version.is_wildcard?
      end
    end

    def is_dependency
      true
    end

    def is_project
      false
    end

    def dependency_config
      fixed_dependencies = @config[:fixed_dependencies]

      if not fixed_dependencies and @config[:dependencies] and not @config[:dependencies].empty?
        raise AssetBender::DependencyError, "#{self} is missing fixed_dependencies, even though it has normal dependencies. Was this not built correctly?"
      end

      fixed_dependencies
    end

  end
end