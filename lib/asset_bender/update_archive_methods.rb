module AssetBender
  module UpdateArchiveMethods

    include HTTPUtils
    include ProcUtils
    include LoggerUtils

    def archive_download_destination(dep)
      File.join @path, archive_name(dep)
    end

    def download_archive(dep)
      url = archive_url dep
      destination_path = archive_download_destination dep
      downloaded_file = nil

      begin
        retry_up_to 3 do 
           downloaded_file = download_file url, destination_path
        end
      rescue
        if not Config.archive_url_fallback.nil?
          fallback_url = Config.archive_url_fallback.call dep

          retry_up_to 3 do 
            downloaded_file = download_file fallback_url, destination_path
          end

          logger.info "Downloaded archive via fallback url: #{fallback_url}"
        else
          raise
        end 
      end

      downloaded_file.path
    end

    def latest_build_in_archive_for(dep)
      @filesystemFetcher.fetch_last_build(dep)
    end

    def build_already_downloaded?(dep)
      expected_path = File.join @path, dep.name, dep.version.path_format
      true if File.directory? expected_path
    end

    def update_dependencies_for(project_or_dep, dep_chain = nil)

      logger.info "Fetching dependencies for #{project_or_dep}..."
      unfulfilled_deps = project_or_dep.fetch_versions_for_dependencies :fetcher => @remoteFetcher 

      if unfulfilled_deps.empty?
        logger.info "#{project_or_dep} has no static dependencies, continuing."

      else
          logger.info "Expanding dependencies..."
          deps_to_still_recurse_over = []

          # Keep track of the dependency chain to detect circular dependencies
          if not dep_chain
            dep_chain = DependencyChain.new project_or_dep
          else
            dep_chain.add_link project_or_dep
          end

          unfulfilled_deps.each do |dep_or_proj|

              # Don't allow circular dependencies 
              if dep_or_proj.name == dep_chain.parent.name
                dep_chain.add_link dep_or_proj
                raise CircularDependencyError.new dep_chain
              end

              if dep_or_proj.is_a? LocalProject
                  logger.info "Locally serving #{dep_or_proj}, skipping dependency (from #{project_or_dep})"
              elsif build_already_downloaded? dep_or_proj
                  logger.info "#{dep_or_proj} already satisfied"
              else
                dep = dep_or_proj 

                # Download archive (with retries)
                archive_file = download_archive dep

                # Determine which pointer files to include and ignore
                tar_options = build_tar_options dep

                # Extract the archive
                unless system "cd #{@path}; tar xzf #{archive_file} #{tar_options} && rm #{archive_file}"
                  system "rm {File.join @path, archive_file}"

                  raise AssetBender::ArchiveError.new "Error unarchiving #{archive_file}, either there was a network hiccup, or the file is malformed: #{archive_url(dep)}"
                end

                # Modify legacy pointers if necessary
                if not Config.modify_extracted_archive.nil?
                  Config.modify_extracted_archive.call @path, dep, existing_dep_pointers_for(dep)
                end

                # Actually load the dependency from the freshly un-tarred archive
                resolved_dep = get_dependency dep.name, dep.version

                deps_to_still_recurse_over << resolved_dep
              end
          end

          # Recursively grab dependencies for the projects just unarchived
          begin
            deps_to_still_recurse_over.each do |dep|
              update_dependencies_for dep
            end
          rescue CircularDependencyError => e

            # Output the circular dep error message
            puts "\n\n"
            puts e.message

            puts "\nDeleting the builds that lead up to this..."
            e.dep_chain.each do |project_or_dep|
              delete_dependency project_or_dep if project_or_dep.is_a? Dependency
            end

            puts "\n\n"
            $stdout.flush
            abort('Aborting build due to circular dependency.')
          end
      end
    end

    def fetch_latest_version_for_dep(dep)
      @remoteFetcher.resolve_version_for_project dep.name, Version.new("edge")
    end

    def fetch_latest_major_version_for_dep(dep)
      @remoteFetcher.resolve_version_for_project dep.name, Version.new("#{dep.version.major}.x.x")
    end

    def fetch_latest_minor_version_for_dep(dep)
      @remoteFetcher.resolve_version_for_project dep.name, Version.new("#{dep.version.major}.#{dep.version.minor}.x")
    end

    # If the build we are extracting is older than the latest build for this project in the archive,
    # then ignore all the pointer files when extracting because we don't want them to be overridden
    # by older ones.
    def build_tar_options(dep)
      tar_options = "--exclude '#{AssetBender::Config.build_hash_filename}'"

      # Only exclude the pointers that already exist (just in case a non-recommended version was
      # extracted earlier and didn't have all the pointers)
      tar_options += existing_dep_pointers_for(dep).map do |pointer|
        exclude_this_pointer = true

        if 'edge' == pointer && dep.version > fetch_latest_version_for_dep(dep)
          exclude_this_pointer = false

        elsif /^latest-\d+$/ =~ pointer && dep.version > fetch_latest_major_version_for_dep(dep)
          exclude_this_pointer = false

        elsif /^latest-\d+.\d+$/ =~ pointer && dep.version > fetch_latest_minor_version_for_dep(dep)
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
      end.compact
    end

  end
end