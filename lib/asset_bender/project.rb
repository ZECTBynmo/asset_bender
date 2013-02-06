require 'set'

module AssetBender
  class Project
    include ConfLoaderUtils
    include LoggerUtils
    extend LoggerUtils

    FILENAME = 'component.json'

    attr_reader :name, :aliases,
                :version, :recommended_version,
                :description, :dependencies_by_name

    def initialize(config)
      @config = config

      @name = config['name']
      @description = config['description']

      @version = AssetBender::Version.new config['version']
      @recommended_version = AssetBender::Version.new config['recommended_version']

      @dependencies_by_name = build_dependencies_by_name_with_semvers config['dependencies']
      @aliases = Set.new
    end

    def self.load_from_file(path)
      config_file = project_config_path(path)
      logger.info "Loading project from file: #{config_file}"

      self.new load_json_or_yaml_file config_file
    end

    def dependency_names
      @dependencies_by_name.keys
    end

    private

    def self.project_config_path(path)
      File.expand_path File.join path, FILENAME
    end

    def build_dependencies_by_name_with_semvers(dep_config)
      deps_with_semvers = {}

      (dep_config || {}).each_with_object(deps_with_semvers) do |(dep_name, ver_str), new_hash|
        new_hash[dep_name] = AssetBender::Version.new ver_str
      end

      deps_with_semvers
    end

    # Returns an array of project and/or dependency objects that represent match
    # the versions specified in this project's comonent.json
    #
    # Note, this is meomized and is only called once (unless the force_reresolve
    # option is passed)
    def resolved_dependencies(options = nil)
      options ||= {}
      @_resolved_dependencies = nil if options[:force_reresolved]

      if @_resolved_dependencies.nil?
        logger.error 'TODO IMPLEMENT RESOLVED_DEPENDENCIES'

      end

      @_resolved_dependencies
    end

  end

end
