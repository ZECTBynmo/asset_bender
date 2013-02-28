require 'net/http'
require File.expand_path('../hubspot_static_deps',  __FILE__)

class ArchiveDownloadError < StandardError
    attr_reader :response 

    def initialize(response)
        @response = response
    end
end

class LocalStaticArchive
    def initialize(archive_dir)
        @archive_dir = archive_dir
        check_if_archive_directory_exists
    end

    def archive_dir
        File.expand_path @archive_dir
    end

    def check_if_archive_directory_exists
        if not File.directory? archive_dir
          puts "You, don't have a ~/.hubspot directory, creating it\n" 
          puts "That probably also means that you haven't run './hs-static update-deps -p <path-to-your-projects' yet, either (which you should do).\n"

            Dir::mkdir archive_dir
        end
    end

    def update_dependencies_for(project_path, options = nil)
        options = { :remote => true, :skip_self_build_names => true } unless options
        build_name = options.delete(:build_name)
        use_prebuilt_json = options.delete(:use_prebuilt_json)

        if use_prebuilt_json
            static_deps = PrebuiltStaticDependencies::build_from_filesystem project_path, build_name
        else
            static_deps = StaticDependencies::build_from_filesystem project_path, build_name
        end

        project_name = static_deps.project_name
        all_build_names = {}

        # Get the latest build names of static dependencies
        print "\nFetching static dependencies for #{project_name} #{build_name || ''} ..."
        list_of_deps = static_deps.projects_with_dependencies()

        unless list_of_deps.empty?
            print "\n"

            if use_prebuilt_json
                deps = static_deps.fetch_all_latest_static_build_names
            else
                puts "Fetching build names..."
                deps = static_deps.fetch_all_latest_static_build_names "hubspot-static2cdn.s3.amazonaws.com"
            end


            puts "Expanding dependencies..."
            projects_to_recurse_over = []

            deps.each do |dep_name, build_name|
                all_build_names[dep_name] = build_name unless all_build_names[dep_name]

                if options[:served_projects_paths_set] and options[:served_projects_paths_set].include? dep_name
                    puts "    Locally serving #{dep_name}, skipping dependency on #{dep_name}-#{build_name}"
                elsif build_already_downloaded? dep_name, build_name
                    puts "    #{dep_name}-#{build_name} already satisfied"
                else
                    # Download archive (with retries)
                    retry_count = 0
                    archive_file = nil

                    while retry_count < 3 and not archive_file do
                        begin
                            archive_file = download_archive dep_name, build_name
                            puts "    #{archive_file}"
                        rescue
                            retry_count += 1
                            raise if retry_count > 2
                            puts "    Retry #{retry_count}..."
                        end
                    end

                    # Extract the archive

                    tar_options = ""

                    # If the build we are extracting is older than the latest build for this project in the archive,
                    # then ignore all the pointer files when extracting because we don't want them to be overridden
                    # by older ones.
                    existing_build = latest_build_for_project dep_name

                    if existing_build and StaticDependencies::compare_build_names(existing_build, build_name) > 0
                        tar_options = "--exclude 'premunged-static-contents-hash.md5'"

                        # Only exclude the pointers that already exist (just in case a major version was extracted earlier and didn't have all the pointers)
                        tar_options += current_pointers_for_project(dep_name).map do |pointer|
                            " --exclude '#{pointer}'"
                        end.join(' ')
                    end

                    unless system "cd #{archive_dir}; tar xzf #{archive_file} #{tar_options} && rm #{archive_file}"
                        system "rm {File.join archive_dir, archive_file}"
                        raise "Error unarchiving #{archive_file}, either there was a S3/network hiccup, or the file on s3 is malformed: #{archive_url(dep_name, build_name)}"
                    end

                    build_name = "static-#{build_name}" unless build_name.start_with? 'static-'

                    # Ensure there are edge pointers if they don't exist
                    if not File.exist?("#{archive_dir}/#{dep_name}/latest-qa") and not File.exist?("#{archive_dir}/#{dep_name}/edge-qa")
                        system "cp #{archive_dir}/#{dep_name}/current-qa #{archive_dir}/#{dep_name}/latest-qa"
                        system "cp #{archive_dir}/#{dep_name}/current-qa #{archive_dir}/#{dep_name}/edge-qa"
                    end

                    projects_to_recurse_over << {
                        :path => File.join(archive_dir, dep_name),
                        :build_name => build_name
                    }
                end
            end

            # Recursively grab dependencies for the projects just unarchived
            projects_to_recurse_over.each do |project|
                sub_build_names = update_dependencies_for project[:path], { :build_name => project[:build_name], :use_prebuilt_json => true }
                all_build_names = sub_build_names.update(all_build_names)
            end
        else
            # puts "\nThis project has no static dependencies, continuing."
            puts " None"
        end

        all_build_names
    end

    def current_pointers_for_project(project_name)
        Dir.glob("#{archive_dir}/#{project_name}/*").collect do |path|
            filename = File.basename path
            filename if filename.start_with? 'current' or filename.start_with? 'latest' or filename.start_with? 'edge'
        end.compact!
    end


    def archive_name(project_name, build_name)
        "#{project_name}-#{build_name}-src.tar.gz"
    end

    def archive_url(project_name, build_name)
         "http://#{DEFAULT_STATIC_DOMAIN}/#{archive_name(project_name, build_name)}"
    end

    def project_archive_path(project_name)
        project_path = File.join archive_dir, project_name
        project_path if File.directory?(project_path) 
    end

    def latest_build_for_project(project_name)
        project_path = project_archive_path project_name

        if project_path
            latest_qa_pointer = File.join project_path, 'edge-qa'

            begin
                latest_build = File.open latest_qa_pointer, 'r' do |f|
                    return f.read()
                end.strip
            rescue
                # Fall back on the deprecated "latest-qa" pointer
                latest_qa_pointer = File.join project_path, 'latest-qa'

                latest_build = File.open latest_qa_pointer, 'r' do |f|
                    return f.read()
                end.strip
            end
        end
    end

    def build_already_downloaded?(project_name, build_name) 
        project_path = project_archive_path project_name

        if project_path
            static_folder_path = File.join project_path, build_name
            true if File.directory?(static_folder_path)
        end
    end

    def download_archive(project_name, build_name)
        path = File.join(archive_dir, archive_name(project_name, build_name))
        f = open path, "w"

        uri = URI.parse archive_url(project_name, build_name)

        begin
            Net::HTTP.start(uri.host, uri.port) do |http|
                http.request_get(uri.path) do |resp|
                    raise ArchiveDownloadError.new(resp) unless resp.kind_of? Net::HTTPSuccess

                    resp.read_body do |segment|
                        f << segment
                        sleep 0.005
                    end
                end
            end

            f.path
        rescue ArchiveDownloadError => e
            puts "Error downloading #{uri}!" 
            puts "#{e.response.code}: #{e.response.message}"
            raise e
        rescue
            puts $!.inspect, $@
            raise "Error downloading #{uri}!" 
        ensure
            f.close()
        end
    end

    def projects_in_archive
        Dir.glob "#{archive_dir}/*/"
    end
end
