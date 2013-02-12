require "asset_bender/project/render_methods"

module AssetBender
  class FilesystemProject < Project
    attr_reader :path

    include RenderMethods

    def initialize(config, path_to_project)
      super config
      @path = path_to_project

      check_for_alias
      check_for_spec_directory
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