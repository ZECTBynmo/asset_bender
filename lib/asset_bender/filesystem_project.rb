require "asset_bender/project/render_methods"

module AssetBender
  class AbstractFilesystemProject < AbstractProject
    attr_reader :path

    include RenderMethods

    def initialize(config, path_to_project)
      super config
      @path = path_to_project
    end

    def to_s
      "#{@name} #{@version}"
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

    # Returns an array of project and/or dependency objects that represent match
    # the versions specified in this project's component.json
    #
    # Note, this is meomized and is only called once (unless the force_reresolve
    # option is passed)
    def resolved_dependencies(options = nil)
      options ||= {}
      @_resolved_dependencies = nil if options[:force_reresolved]
      fetcher = options[:fetcher] || AssetBender::Fetcher.new

      if @_resolved_dependencies.nil?
        @_resolved_dependencies = []

        @dependencies_by_name.each do |dep, version|
          if AssetBender::ProjectsManager.project_exists? dep
            resolved_dep = AssetBender::ProjectsManager.get_project dep
          else
            resolved_version = fetcher.resolve_version_for_project dep, version
            resolved_dep = AssetBender::DependenciesManager.get_dependency dep, resolved_version
          end

          @_resolved_dependencies << resolved_dep
        end
      end

      @_resolved_dependencies
    end

    def is_resolved?
      !@_resolved_dependencies.nil?
    end

  end
end