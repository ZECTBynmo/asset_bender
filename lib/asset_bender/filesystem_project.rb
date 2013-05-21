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
      path = File.expand_path path
      project_config = load_config_from_file path
      self.new project_config, path
    end

    # Fetches the version for every single depenedency in this project.
    # Returns a list of UnfulfilledDependency and/or LocalProject instances
    def fetch_versions_for_dependencies(options = {})
      results = []
      fetcher = options[:fetcher] || AssetBender::Fetcher.new
      
      @dependencies_by_name.each do |dep_name, version|
        if AssetBender::ProjectsManager.project_exists? dep_name
          results << AssetBender::ProjectsManager.get_project(dep_name)
        else
          resolved_version = version.is_fixed? ? version : fetcher.resolve_version_for_project(dep_name, version)
          results << AssetBender::UnfulfilledDependency.new(dep_name.to_s, resolved_version)
        end
      end

      results
    end

    # Returns an array of project and/or dependency objects that represent match
    # the versions specified in this project's component.json
    #
    # Note, this is meomized and is only called once (unless the force_reresolve
    # option is passed)
    def resolved_dependencies(options = {})
      @_resolved_dependencies = nil if options[:force_reresolve]

      if @_resolved_dependencies.nil?
        @_resolved_dependencies = []

        unfulfilled_deps = fetch_versions_for_dependencies options

        unfulfilled_deps.each do |dep_or_proj|
          if dep_or_proj.is_a? LocalProject
            resolved_dep = dep_proj

          elsif !dep_or_proj.version || !AssetBender::DependenciesManager.dependency_exists?(dep_or_proj.name, dep_or_proj.version)
            raise AssetBender::Error.new "Unknown dependency #{dep_or_proj}, have you run update deps (and made sure all necessary dependencies are configured?)"

          else
            resolved_dep = AssetBender::DependenciesManager.get_dependency dep_or_proj.name, dep_or_proj.version
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

    def locally_resolved_dependencies(options = nil)
      options ||= {}
      fetcher = options[:fetcher] || AssetBender::LocalFetcher.new
      recurse = options[:recurse] || false

      deps = resolved_dependencies({ :fetcher => fetcher })

      if recurse
        deps_to_recurse = deps.dup
        deps = Set.new deps

        while not deps_to_recurse.empty?
          # Pop off the stack and add to the complete deps set if it doesn't already exist
          current_dep = deps_to_recurse.shift
          deps.add current_dep

          # Appened all this dep's deps to the stack to recurse later
          deps_to_recurse.concat current_dep.resolved_dependencies
        end

        deps = deps.to_a
      end

      deps
    end

    def is_resolved?
      !@_resolved_dependencies.nil?
    end

    def is_project
      true
    end

  end
end