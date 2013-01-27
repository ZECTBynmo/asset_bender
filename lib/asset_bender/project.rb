module AssetBender
  class Project
    include ConfUtils
    FILENAME = 'component.json'

    attr_reader :name, :description, :dependency_map

    def initialize(config)
      @config = config

      @name = config['name']
      @description = config['description']
      @version = VersionUtils.parse_version config['version']

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
        new_hash[dep_name] = VersionUtils.parse_version ver_str
        print "\n", "semver:  #{new_hash[dep_name].inspect}", "\n\n"
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
