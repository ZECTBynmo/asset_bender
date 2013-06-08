module AssetBender
  module Commands
    class UpdateDeps < BaseCommand

      def parse_options
        setup_command_env

        # Only update the projects passed in on the command line (if any).
        # Otherwise, update all the projects in the bender config
        @projects_to_update = @args.map { |p| get_project_by_name_or_path(p) }
        @projects_to_update = ProjectsManager.available_projects if @projects_to_update.empty?
      end

      def run
        abort "No projects to update" if @projects_to_update.empty?

        logger.warn "Clearing the cache..."
        FileUtils.rm_r Config.temp_path if Dir.exist? Config.temp_path

        local_archive = LocalArchive.new Config.archive_dir

        @projects_to_update.each do |project|
          logger.info "Updating depdendencies for #{project.name}"
          local_archive.update_dependencies_for project
        end
      end

    end
  end
end
