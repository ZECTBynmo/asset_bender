require 'guard'

module AssetBender
  module Commands
    class Serve < GuardCommand

      def parse_options
        setup_command_env

        # Only update the projects passed in on the command line (if any).
        # Otherwise, update all the projects in the bender config
        @projects_to_update = @args.map { |p| get_project_by_name_or_path(p) }
        @projects_to_update = ProjectsManager.available_projects if @projects_to_update.empty?
      end

      def run
        # Watch all the local projects, the bender config folder, and the actual
        # asset bender source (if in contributor mode)
        dirs_to_watch = @projects_to_update.map { |p| p.path }
        dirs_to_watch << '~/.bender/'
        groups = ['asset_bender']

        if ENV['BENDER_DEBUG_RELOAD']
          dirs_to_watch << bender_root
          groups << 'server'
        end

        start_guard({
          :watchdir => dirs_to_watch,
          :groups => groups
        })
      end

    end
  end
end
