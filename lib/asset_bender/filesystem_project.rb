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
      @_resolved_dependencies = nil if options[:force_reresolve]
      fetcher = options[:fetcher] || AssetBender::Fetcher.new

      if @_resolved_dependencies.nil?
        @_resolved_dependencies = []

        @dependencies_by_name.each do |dep, version|
          if AssetBender::ProjectsManager.project_exists? dep
            resolved_dep = AssetBender::ProjectsManager.get_project dep

          else
            resolved_version = version.is_fixed? ? version : fetcher.resolve_version_for_project(dep, version)

            if !resolved_version || !AssetBender::DependenciesManager.dependency_exists?(dep, resolved_version)
              raise AssetBender::Error.new "Unknown dependency #{dep}, have you run update deps (and made sure all necessary dependencies are configured?)"
            else
              resolved_dep = AssetBender::DependenciesManager.get_dependency dep, resolved_version
            end
          end

          @_resolved_dependencies << resolved_dep
        end

        # Ensure all deps are resolved recursively (but don't include them in
        # returned results)
        @_resolved_dependencies.each do |dep|
          dep.resolved_dependencies options
        end
      end


      @_resolved_dependencies
    end

    def is_resolved?
      !@_resolved_dependencies.nil?
    end

  end
end