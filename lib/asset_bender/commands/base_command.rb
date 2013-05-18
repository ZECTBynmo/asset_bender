module AssetBender
  module Commands
    class BaseCommand

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

      def setup_env(env_options)
        env_options ||= {}
        env_options[:extra_projects] ||= []

        AssetBender::Config.load_all_base_config_files

        @sprockets = Sprockets::Environment.new(bender_root, { :must_include_parent => true })

        ProjectsManager.setup Config.local_projects + env_options[:extra_projects]
        DependenciesManager.setup Config.archive_dir

        ProjectsManager.available_projects.each do |project|
          @sprockets.append_path project.path
        end
      end

    end
  end
end
