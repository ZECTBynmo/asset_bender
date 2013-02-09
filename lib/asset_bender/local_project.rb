require 'etc'

require "asset_bender/project/render_methods"
require "asset_bender/project/git_methods"


module AssetBender
  class LocalProject < Project
    attr_reader :path, :spec_directory

    POSSIBLE_SPEC_DIRS = [
      'static/test/spec',
      'spec'
    ]

    include RenderMethods
    include GitMethods

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

    def parent_path
      File.split(@path)[0]
    end

    def self.load_from_file(path)
      project_config = load_config_from_file path
      self.new project_config, path
    end
  end

end