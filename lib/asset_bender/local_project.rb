
module AssetBender
  class LocalProject < Project
    attr_reader :path, :spec_directory

    POSSIBLE_SPEC_DIRS = [
      'static/test/spec',
      'spec'
    ]

    def initialize(config, path_to_project)
      super config
      @path = path_to_project

      check_for_alias
      check_for_spec_directory
    end

    def version_to_build
      if @version.is_wildcard
        @version
      else
        raise "This project has a fixed version specified, so version_to_build doesn't make sense"
      end
    end

    def check_for_alias
      parent_directory = File.basename @path
      @aliases.add parent_directory if parent_directory != @name
    end

    def has_specs?
      !@spec_directory.nil?
    end

    def check_for_spec_directory
      POSSIBLE_SPEC_DIRS.each do |dir|
        potential_spec_dir = File.join @path, dir
        return @spec_dir = potential_spec_dir if File.directory? potential_spec_dir
      end
    end

    def self.load_from_file(path)
      config_file = self.project_config_path(path)
      logger.info "Loading local project from file: #{config_file}"

      self.new load_json_or_yaml_file(config_file), path
    end
  end
end