require 'asset_bender/patches/custom_manifiest_compiler'

module AssetBender
  module Commands
    class Precompile

      def initialize(global_options, options, args)
        @project_input = args[0]
        @project_path = File.expand_path @project_input
        @project_name = File.basename @project_path

        @output = options[:output]
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

      def run
        setup_env({ :extra_projects => [@project_path] })

        manifest = Sprockets::Manifest.new(@sprockets.index, @output)
        manifest.compile_prefixed_files_without_digest "#{@project_name}/"
      end

    end
  end
end
