module AssetBender
  class Project
    include ConfUtils

    FILENAME = 'component.json'

    attr_reader :name, :version, :recommended_version,
                :description, :dependency_map

    def initialize(config)
      @config = config

      @name = config['name']
      @description = config['description']
      @version = AssetBender::Version.new config['version']
      @recommended_version = AssetBender::Version.new config['recommended_version']

      @dependency_map = build_dependency_map_with_semvers config['dependencies']
    end

    def self.load_from_file(path)
      Project.new load_json_or_yaml_file File.join path, FILENAME
    end

    def dependency_names
      @dependency_map.keys
    end

    private

    def build_dependency_map_with_semvers(dep_config)
      deps_with_semvers = {}

      (dep_config || {}).each_with_object(deps_with_semvers) do |(dep_name, ver_str), new_hash|
        new_hash[dep_name] = AssetBender::Version.new ver_str
      end

      deps_with_semvers
    end

  end

  class ResolvedProect < Project

    def initialize(config)
    super
    end
  end
end
