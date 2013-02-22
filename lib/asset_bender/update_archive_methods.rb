module AssetBender
  module UpdateArchiveMethods

    include HTTPUtils
    include ProcUtils

    def archive_download_destination(dep)
      File.join @path, archive_name(dep)
    end

    def download_archive(dep)
      url = archive_url dep
      destination_path = archive_download_destination dep
      downloaded_file = download_file url, destination_path

      if downloaded_file.nil?
        logger.error "Failed to download archive for #{dep.name}."
        nil
      else
        downloaded_file.path
      end
    end

    def latest_build_in_archive_for(dep)
      @filesystemFetcher.fetch_last_build(dep)
    end

    def build_already_downloaded?(dep) 
      expected_path = File.join @path, dep.name, dep.version.path_format
      true if File.directory? expected_path
    end

    def update_dependencies_for(project_or_dep)

      logger.info "Fetching dependencies for #{project_or_dep}..."
      resolved_dependencies = project_or_dep.resolved_dependencies :fetcher => @remoteFetcher 

      if resolved_dependencies.empty?
        #puts "  This project has no static dependencies, continuing."

      else
          logging.info "Expanding dependencies..."
          deps_to_still_recurse_over = []

          resolved_dependencies.each do |resolved_proj_or_dep|
              if resolved_proj_or_dep.is_a? AssetBender::LocalProject
                  logger.info "Locally serving #{resolved_proj_or_dep}, skipping dependency on #{project_or_dep}"
              elsif build_already_downloaded? resolved_proj_or_dep
                  logger.info "#{resolved_proj_or_dep} already satisfied"
              else
                resolved_dep = resolved_proj_or_dep

                # Download archive (with retries)
                archive_file = retry_up_to 3 do 
                  download_archive resolved_dep
                end

                # Determine which pointer files to include and ignore
                tar_options = build_tar_options resolved_dep

                # Extract the archive
                unless system "cd #{@path}; tar xzf #{archive_file} #{tar_options} && rm #{archive_file}"
                  system "rm {File.join @path, archive_file}"
                  raise AssetBender::ArchiveError.new "Error unarchiving #{archive_file}, either there was a network hiccup, or the file is malformed: #{archive_url(resolved_dep)}"
                end

                deps_to_still_recurse_over << resolved_dep
              end
          end

          # Recursively grab dependencies for the projects just unarchived
          deps_to_still_recurse_over.each do |dep|
            update_dependencies_for dep
          end
      end
    end

    def build_tar_options(resolved_dep)
      tar_options = "--exclude '#{AssetBender::Config.build_hash_filename}'"

      # If the build we are extracting is older than the latest build for this project in the archive,
      # then ignore all the pointer files when extracting because we don't want them to be overridden
      # by older ones.
      latest_version = resolve_version_for_project resolved_dep.name, Verson.new("edge")
      latest_major = resolve_version_for_project resolved_dep.name, Verson.new("#{resolved_dep.major}.x.x")
      latest_minor = resolve_version_for_project resolved_dep.name, Verson.new("#{resolved_dep.major}.#{resolved_dep.minor}.x")

      this_version = resolved_dep.version

      # Only exclude the pointers that already exist (just in case a non-recommendedversion was extracted earlier and didn't have all the pointers)
      tar_options += current_pointers_for_project(dep_name).map do |pointer|
        exclude_this_pointer = true

        if 'edge' == pointer && this_version > latest_version
          exclude_this_pointer = false

        elsif /^latest-\d+$/ =~ pointer && this_version > latest_major
          exclude_this_pointer = false

        elsif /^latest-\d+.\d+$/ =~ pointer && this_version > latest_minor
          exclude_this_pointer = false
        end

        return " --exclude '#{pointer}'" if exclude_this_pointer
        ""
      end.join(' ')
    end

    # All of the build pointers in our archive directory for a specific dependency
    def existing_dep_pointers_for(dep)
      Dir.glob("#{@path}/#{dep.name}/*").collect do |path|
        filename = File.basename path
        filename if filename.start_with? 'current' or filename.start_with? 'latest' or filename.start_with? 'edge'
      end.compact!
    end

  end
end