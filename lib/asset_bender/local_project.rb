require 'etc'

CurrentUser = Etc.getlogin

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
      @alias = parent_directory if parent_directory != @name
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

    def last_modified
      stat = File.stat @path
      stat.mtime
    end

    def pretty_path
      output = @path
      output.sub /\/(Users|home)\/#{CurrentUser}\//i, '~/'
    end

    def parent_path
      File.split(@path)[0]
    end

    def self.load_from_file(path)
      config_file = self.project_config_path(path)
      logger.info "Loading local project from file: #{config_file}"

      begin
        project_config = load_json_or_yaml_file(config_file)
      rescue
        logger.error "Couldn't load #{config_file}, allowing for now..."
        project_config = {
          "name" => File.basename(path),
          "version" => "0.1.x",
          "recommended_version" => "0.1.x",
        }
        print "\n", "faked project_config:  #{project_config.inspect}", "\n\n"
      end

      self.new project_config, path
    end
  end
end