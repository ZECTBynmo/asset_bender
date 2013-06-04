require 'set'

module AssetBender

  class DependenciesManager
    include CustomSingleton
    include LoggerUtils

    # Load the global singleton that will be availble as:
    #
    #    AssetBender::DependenciesManager.get_whatever_setting
    #
    def self.instance
      raise AssetBender::Error.new "AssetBender::DependenciesManager has not been setup yet" unless defined? @@global_instance
      @@global_instance
    end

    # Called to setup the DependenciesManager singleton
    def self.setup(*args)
      @@global_instance = self.send :new, *args
    end

    def initialize(local_archive_path)
      @local_archive = AssetBender::LocalArchive.new local_archive_path
    end

    # Delegate class methods to singleton insance
    def self.method_missing(sym, *args)
      instance.send sym, *args
    end

    # Returns a set of all the dependencies that are in the archive
    def available_dependency_names
      @local_archive.available_dependencies
    end

    # Returns a set of all the dedpendency paths in the archive (that might house multiple versions)
    def available_dependency_parent_paths
      @local_archive.available_dependency_parent_paths
    end

    # Returns a hash of dependency names to an array of versions available
    def available_dependencies_and_versions
      @versions_for_each_dep ||= available_dependency_names.each_with_object({}) do |dep_name, result|
        result[dep_name] = @local_archive.available_versions_for_dependency dep_name
      end
    end

    # Returns an array of all dependencies in the archive (including multiple
    # versions of the same dependency)
    def all_available_dependencies
      @all_deps ||= available_dependencies_and_versions.map do |dep_name, versions|
        versions.map { |version| get_dependency dep_name, version}
      end.flatten
    end

    # Returns a hash of 
    def dependees_by_dependency(source_projects)
      result = {}

      source_projects.each do |project|
        project.locally_resolved_dependencies.each do |proj_dep|
          result[proj_dep.name] ||= Set.new
          result[proj_dep.name].add project
        end
      end

      result
    end

    # Returns the project instance that represents the passed in path, by
    # looking for a "/<project_name>/" that matches one of the currently
    # available projects.
    #
    # Returns nil if no project is found
    def get_project_from_path(url_or_path)
      name = VersionUtils::look_for_string_in_path url_or_path, available_project_names
      get_project name if name
    end

    def dependency_exists?(dep_name, resolved_version)
      @local_archive.dependency_exists? dep_name, resolved_version
    end

    # Returns the dependency instance from the passed name and resolved version
    # Fails and raises an error if a dependency with that version doesn't exist
    # in the archive
    def get_dependency(dep_name, resolved_version)
      dependency = @local_archive.get_dependency dep_name, resolved_version

      raise AssetBender::UnknownDependencyError.new "The #{dep_name} #{resolved_version} dependency doesn't exists in your archive (do you need to update deps?)" unless dependency
      dependency
    end

    # Returns the dependency instance that represents the passed in path, by
    # looking for a "/<dep_name>/<version>/" that matches one of the dependencies
    # in the archive.
    #
    # Returns nil if no dependecy with that version is found
    def get_dependency_from_path(url_or_path)
      name, version = VersionUtils::look_for_string_preceding_version_in_path url_or_path, available_dependency_names
      @local_archive.get_dependency name, version 
    end

    def get_project_or_dependency_from_path(url_or_path)
      result = get_project_from_path url_or_path
      result = get_dependency_from_path url_or_path unless result
      result
    end

  end
end