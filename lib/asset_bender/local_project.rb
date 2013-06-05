require "asset_bender/project/git_methods"

module AssetBender
  class LocalProject < AbstractFilesystemProject
    attr_reader :path, :spec_directory

    POSSIBLE_SPEC_DIRS = [
      'static/test/spec',
      'spec'
    ]

    include GitMethods

    def initialize(config, path_to_project)
      super

      check_for_alias
      check_for_spec_directory
    end

    def version_to_build
      if @version.is_wildcard?
        @version
      else
        raise AssetBender::VersionError.new "This project has a fixed version specified, so version_to_build doesn't make sense"
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
        return @spec_directory = potential_spec_dir if File.directory? potential_spec_dir
      end
    end

    def url
      "/#{@name}/"
    end

  end

end