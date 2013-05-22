module AssetBender
  module Commands
    class BaseCommand

      include LoggerUtils

      def initialize(global_options, options, args)
        @global_options = global_options
        @options = options
        @args = args

        parse_options
      end

      def parse_options
      end

      def bender_root
        File.expand_path(File.join(__FILE__, '../../'))
      end

      def setup_env(env_options = {})
        env_options[:extra_projects] ||= []

        AssetBender::Config.load_all_base_config_files

        ProjectsManager.setup Config.local_projects + env_options[:extra_projects]
        DependenciesManager.setup Config.archive_dir
      end

      def setup_sprockets
        @sprockets = Sprockets::Environment.new(bender_root, { :must_include_parent => true })

        ProjectsManager.available_projects.each do |project|
          @sprockets.append_path project.path
        end
      end

      # Returns the project instance by searching for a matching name in the currently
      # loaded projects OR the filesystem path. Requires `setup_env` to have been called
      # first.
      def get_project_by_name_or_path(input)
        if ProjectsManager.project_exists? input
          ProjectsManager.get_project input
        else
          LocalProject.load_from_file input
        end
      end

    end
  end
end