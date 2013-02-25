require 'set'

module AssetBender

  class UnknownProjectError < StandardError; end
  
  class ProjectsManager
    include CustomSingleton
    include LoggerUtils

    attr_reader :served_projects_by_name,  # Also by alias if there is one
                :jasmine_projects

    # Load the global singleton that will be availble as:
    #
    #    AssetBender::ProjectsManager.get_whatever_setting
    #
    def self.instance
      raise AssetBender::Error.new "AssetBender::ProjectsManager has not been setup yet" unless defined? @@global_instance
      @@global_instance
    end

    # Called to setup the ProjectsManager singleton
    def self.setup(*args)
      @@global_instance = self.send :new, *args
    end

    def initialize(project_paths)
      projects = project_paths.map do |project_path|
        begin
          LocalProject.load_from_file File.expand_path project_path
        rescue AssetBender::ProjectLoadError => e
          logger.error e
          nil
        end
      end.compact

      @served_projects_by_name = {}

      projects.each do |project|
        names_and_aliases = [project.name]
        names_and_aliases << project.alias if project.alias

        add_multiple_keys_to_hash @served_projects_by_name, names_and_aliases, project

        @jasmine_projects.add project if project.has_specs?
      end
    end

    # Delegate class methods to singleton insance
    def self.method_missing(sym, *args)
      instance.send sym, *args
    end

    # Returns a list of all the projects that are locally being served
    def available_projects
      Set.new(@served_projects_by_name.values).to_a
    end

    # Returns a list of all the names of projects that are locally being served
    def available_project_names
      @served_projects_by_name.keys
    end

    # Returns whether the specified project is being locally served
    def project_exists?(project_name)
      !@served_projects_by_name[project_name].nil?
    end

    # Returns the project instance from the passed name (or alias)
    # Fails and raises an error if the project doesn't exist
    def get_project(project_name)
      raise AssetBender::UnknownProjectError.new "The #{project_name} project doesn't exists" unless project_exists? project_name
      @served_projects_by_name[project_name]
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

    # Helpers

    def add_multiple_keys_to_hash(hash, keys, value)
      keys.each {|key| hash[key] = value}
    end

  end
end