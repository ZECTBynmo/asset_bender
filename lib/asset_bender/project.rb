require 'set'
require 'asset_bender'

module AssetBender
  class ProjectLoadError < AssetBender::Error; end

  class AbstractProject
    extend ConfLoaderUtils
    include LoggerUtils
    extend LoggerUtils

    FILENAME = 'component.json'

    attr_reader :name, :alias,
                :version, :recommended_version,
                :description, :dependencies_by_name

    def initialize(config)
      @config = config

      @name = @config[:name]
      @description = @config[:description]

      @version = AssetBender::Version.new @config[:version]

      if @config[:recommendedVersion]
        @recommended_version = AssetBender::Version.new @config[:recommendedVersion]
      else
        logger.warn "No recommended version specified for #{@name}, assuming it is the same as the current version."
        @recommended_version = @version.dup
      end

      @dependencies_by_name = build_dependencies_by_name_with_semvers @config[:dependencies]
      @alias = nil
    end

    def self.load_from_file(path)
      self.new load_config_from_file path
    end

    def self.load_config_from_file(path)
      config_file = project_config_path(path)
      logger.info "Loading project from file: #{config_file}"

      begin
        load_json_or_yaml_file config_file
      rescue
        try_fallback_project_loaders path
      end
    end

    def self.try_fallback_project_loaders(path)
      if AssetBender::Config.project_config_fallback
        project_config = AssetBender::Config.project_config_fallback.call path
        raise AssetBender::ProjectLoadError, "Can't load project at #{path}, fallback failed" unless project_config.respond_to? :[]

      elsif AssetBender::Config.allow_projects_without_component_json
        logger.warn "Couldn't load #{config_file}, but allowing since allow_projects_without_component_json is enabled"
        project_config = build_fake_config path

      else
        raise AssetBender::ProjectLoadError, "Can't load project at #{path}, it has no component.json file"
      end

      project_config
    end

    def self.build_fake_config(path)
      {
        "name" => File.basename(path),
        "version" => "0.1.x"
      }
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


  end
end
