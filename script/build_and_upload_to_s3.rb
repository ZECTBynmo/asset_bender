require File.expand_path('../../lib/hubspot_static_deps',  __FILE__)
require File.expand_path('../../lib/local_static_archive',  __FILE__)
require File.expand_path('../../lib/graphite',  __FILE__)

require File.expand_path('../build_helpers',  __FILE__)

PYTHON_DEPLOY_STATIC_PATH = "/usr/share/hubspot/JenkinsTools/python/scripts/python_deploy_static.py"

class StaticError < StandardError
    def init(message)
        @message = message
    end

    def message
        @message
    end
end


# Super hacky giant function for now...
def build(graphite_timer)
    jenkins_name = ENV['JOB_NAME']

    # The main folder where all the building will take place
    jenkins_workspace = static_workspace_dir = ENV['WORKSPACE']
    
    jenkins_root = ENV['JENKINS_ROOT']
    jenkins_root = '/mnt/jenkins-home' if jenkins_root.nil? or jenkins_root.empty?

    puts "\nJenkins root: #{jenkins_root}"

    # For projects have their projects in a sub folder of the repo workspace
    static_workspace_dir = ENV['PROJECT_PATH'] if ENV['PROJECT_PATH']

    # Gets the real project nam
    puts "\nLoading up static_conf.json"
    static_deps = StaticDependencies::build_from_filesystem(static_workspace_dir)
    static_project_name = static_deps.project_name()

    # Detect whether this system is using GNU tools or not to deal with
    # differences between GNU and BSD options. (Ghetto detection from
    # http://stackoverflow.com/questions/8747845/how-can-i-detect-bsd-vs-gnu-version-of-date-in-shell-script)
    is_gnu = system "date --version >/dev/null 2>&1"
    puts "This system is using non-GNU commands" unless is_gnu

    # First stab at using major versions

    # Current static version should be set in the Jenkins build (most apps
    # can let it default to 1). If this matches the major_version below,
    # then current_qa will get updated by this build.
    current_static_version = ENV['CURRENT_STATIC_VERSION'] || 1
    current_static_version = current_static_version.to_i


    # The major version of this build is set in static_conf.json as "major_version".
    # (again most apps can leave this blank). This is the major version of this build
    major_version = static_deps.major_version or 1

    # Build number stuff
    build_name = "#{major_version}.#{ENV['BUILD_NUMBER']}"
    build_revision = ENV['GIT_COMMIT'] or ENV['SVN_REVISION']
    rev_str = "rev: #{build_revision}"

    puts "\nBuilding version #{build_name} of #{jenkins_name}"

    # Temp dir to contain all the static manipulations, etc
    temp_dir = "#{jenkins_workspace}/temp-for-static"
    system "rm -rf #{temp_dir}"
    system "mkdir #{temp_dir}"

    # Custom tmp directory for hs-static
    hs_static_temp_dir = "#{temp_dir}/hs-static-tmp"

    # The ouput dir that will get uploaded to s3 and tarballed
    output_dir = "#{temp_dir}/compiled-output"
    system "mkdir -p #{output_dir}"

    debug_output_dir = "#{temp_dir}/compiled-debug-output"
    system "mkdir -p #{debug_output_dir}"

    # Move the static source to the temp dir
    source_dir = "#{temp_dir}/src/#{static_project_name}"
    system "mkdir -p #{source_dir}"
    system "mv '#{static_workspace_dir}/static' #{source_dir}"


    # Save some logs (still make sense with jenkins?)
    # logs_dir = '%s/logs' % parent_dir
    # system 'mkdir -p %s' % logs_dir)


    # Get the latest build names and download static depencencies
    archive_dir = "#{temp_dir}/static-archive"

    archive, all_build_names = graphite_timer.start 'downloading_static_deps' do
        archive = LocalStaticArchive.new archive_dir
        all_build_names = archive.update_dependencies_for source_dir
        [archive, all_build_names]
    end

    # Build name params to pass to hs-static
    dep_build_name_args = " -b #{static_project_name}:#{build_name} "
    build_names_by_project = { static_project_name => "static-#{build_name}" }

    puts "\nAll build names #{all_build_names.inspect}\n"

    # Kinda assumes hash insert ordering (only available in ruby 1.9.3)
    all_build_names.each do |dep_name, dep_build_name|
        build_names_by_project[dep_name] = dep_build_name
        dep_source_dir = "#{archive.archive_dir}/#{dep_name}/"
        dep_build_name_args += " -b #{dep_name}:#{dep_build_name} "
    end

    static_mode = ""
    static_mode = "-m compressed" unless ENV['DONT_COMPRESS_STATIC']

    building_debug_assets = (not static_mode.empty?)
     
    # If we are compressing assets (which we are most of the time), also compile non-compressed versions for QA/prod hsDebug usage
    if building_debug_assets
        puts "\nPrecompiling assets to #{debug_output_dir}..."

        cmd = "./hs-static -m development -a #{archive_dir} -p #{source_dir} -t #{debug_output_dir} -r #{static_project_name} #{dep_build_name_args} --temp #{hs_static_temp_dir} precompile_assets_only"

        puts "(via #{cmd})"

        graphite_timer.start 'precompile_debug_assets' do
            raise "Error precompiling debug assets" unless system cmd
        end
    end


    # Run the task to precompile assets
    puts "\nPrecompiling assets to #{output_dir}..."

    cmd = "./hs-static #{static_mode} -a #{archive_dir} -p #{source_dir} -t #{output_dir} -r #{static_project_name} #{dep_build_name_args} --temp #{hs_static_temp_dir} precompile"

    puts "(via #{cmd})"

    graphite_timer.start 'precompile_compressed_assets' do
        raise "Error precompiling assets" unless system cmd
    end

    # Just in case it wasn't created
    system "mkdir -p #{output_dir}/#{static_project_name}/static-#{build_name}/"

    current_md5_hash = nil
    begin
        current_md5_hash = File.open("#{output_dir}/#{static_project_name}/static-#{build_name}/premunged-static-contents-hash.md5", &:readline) 
    rescue 
        puts "\n Couldn't find #{output_dir}/#{static_project_name}/static-#{build_name}/premunged-static-contents-hash.md5, this might be an empty static project"
    end

    former_md5_hash = graphite_timer.start 'fetch_latest_built_md5' do
        StaticDependencies::fetch_latest_built_md5_for_project(static_project_name, major_version)
    end

    puts "\ncurrent_md5_hash:  #{current_md5_hash.inspect}"
    puts "\nformer_md5_hash:   #{former_md5_hash.inspect}\n"

    hash_is_the_same = current_md5_hash && former_md5_hash && current_md5_hash == former_md5_hash

    current_static_deps = all_build_names
    former_static_deps = graphite_timer.start 'fetch_latest_build_dependencies_file' do
        StaticDependencies::fetch_latest_built_dependencies(static_project_name, major_version)
    end

    puts "\n", "current_static_deps:  #{current_static_deps.inspect}"
    puts "\n", "former_static_deps:  #{former_static_deps.inspect}", "\n"

    deps_are_the_same = current_static_deps && former_static_deps && current_static_deps == former_static_deps

    if hash_is_the_same and deps_are_the_same and not ENV['FORCE_S3_UPLOAD']
        puts "\nContents and depencencies are identical to previous build. Skipping s3 upload.\n\n"

        graphite_timer.start 'fetch_previous_build_conf' do
            download_previous_build_conf static_project_name, major_version, "#{source_dir}/static/"
        end

        copy_over_conf_to_python_module static_project_name, static_workspace_dir, "#{source_dir}/static/"
        return false
    end

    if ENV['RUN_JASMINE_TESTS'] 
        print "\n", "Running jasmine tests\n"
        graphite_timer.start 'jasmine_test_duration' do
            # Run a jasmine test using the just compiled output
            cmd = "./hs-static -m precompiled -p #{source_dir} -t #{output_dir} --headless -a #{archive_dir} -b #{static_project_name}:#{build_name} jasmine"
            puts "(via #{cmd})"

            # Stream the jasmine output
            IO.popen cmd do |f|
                f.each do |line|
                    puts line
                end
            end

            exit_code = $?
            # print "\n", "Exit code:  #{exit_code.inspect}", "\n\n"

            raise "Error running jasmine tests" unless exit_code.success?
        end
    end


    now_str = Time.now.to_s
    info_str = "#{static_project_name}-#{build_name}   #{rev_str}   #{now_str}"

    # Log the build info for this specific build
    system "echo #{info_str} > #{output_dir}/#{static_project_name}/static-#{build_name}/info.txt"

    # Log of all of build names, dates, and revsions for each project
    # system "echo #{info_str} >> #{logs_dir}/#{static_project_name}"

    # Grab the most edge version build (of any major_version)
    current_edge_version = StaticDependencies::fetch_latest_production_build(static_project_name, nil)

    # If this is the first time this project has been built or if this is the most edge version, create the edge pointers
    is_edge_version = current_edge_version.nil? || StaticDependencies::compare_build_names("static-#{build_name}", current_edge_version) == 1

    puts "\nThis #{build_name} > #{current_edge_version} => #{is_edge_version}"

    if is_edge_version
        # Note, there should be no difference between "-qa" and non "-qa" edge pointers
        system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/latest-qa"     # Deprecated
        system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/latest"        # Deprecated
        system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/edge-qa"
        system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/edge"
    end

    system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/latest-version-#{major_version}-qa"

    # Write a shortcut for "current-qa" if we are deploying the current version
    is_current_version = current_static_version == major_version

    if is_current_version
        system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/current-qa"
    else
        puts "\n", "Current static version (#{current_static_version}) doesn't match this build's major version (#{major_version}), skipping the 'current-qa' pointer"
    end

    # If this is the first time this major version has been built, create the prod pointer(s) as well
    if not StaticDependencies::fetch_latest_production_build(static_project_name, major_version)
        puts "\n", "This is the first time building major version #{major_version}, creating the prod latest-version-#{major_version} pointer"

        system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/latest-version-#{major_version}"

        if major_version == 1
            puts "Also building the current pointer for the first time"
            system "echo static-#{build_name} > #{output_dir}/#{static_project_name}/current"
        end
    end


    # Build a fixed-in-time static_conf.json (and prebuilt_recursive_static_conf.json) in the compiled output
    static_deps.create_static_deps_file_with_build "#{output_dir}/#{static_project_name}/static-#{build_name}/static_conf.json", build_name
    StaticDependencies::create_recursive_fixed_static_deps_file "#{output_dir}/#{static_project_name}/static-#{build_name}/prebuilt_recursive_static_conf.json", static_project_name, build_name, all_build_names

    # Zip up the whole compiled static dir
    archive_name = "#{static_project_name}-static-#{build_name}.tar.gz"
    system "cd #{output_dir}; tar cvzf #{archive_name} --exclude=.svn  --exclude=.git #{static_project_name}/"

    # Copy all the latest and current pointers to the source output
    system "cp #{output_dir}/#{static_project_name}/latest-version-* #{source_dir}/"

    if is_edge_version
        system "cp #{output_dir}/#{static_project_name}/latest* #{source_dir}/"
        system "cp #{output_dir}/#{static_project_name}/edge* #{source_dir}/"
    end

    if is_current_version
        system "cp #{output_dir}/#{static_project_name}/current* #{source_dir}/"
    end

    # Copy over the fixed static_conf.json files and info.txt to the source output
    system "cp #{output_dir}/#{static_project_name}/static-#{build_name}/static_conf.json #{source_dir}/static/static_conf.json"
    system "cp #{output_dir}/#{static_project_name}/static-#{build_name}/prebuilt_recursive_static_conf.json #{source_dir}/static/prebuilt_recursive_static_conf.json"
    system "cp #{output_dir}/#{static_project_name}/static-#{build_name}/info.txt #{source_dir}/static/info.txt"

    copy_over_conf_to_python_module static_project_name, static_workspace_dir, "#{source_dir}/static/"

    # Copy over the two static_conf.json files to the top level workspace (so they get included in the egg)
    # TODO: I think this isn't needed anymore (the copy_over_conf_to_python_module func should handle it)
    system "mkdir -p #{static_workspace_dir}/static/"
    system "cp #{output_dir}/#{static_project_name}/static-#{build_name}/static_conf.json #{static_workspace_dir}/static/static_conf.json"
    system "cp #{output_dir}/#{static_project_name}/static-#{build_name}/prebuilt_recursive_static_conf.json #{static_workspace_dir}/static/prebuilt_recursive_static_conf.json"

    # Make the source directory have a build name
    system "cd #{source_dir}; mv static static-#{build_name}"

    puts "\nSed-replacing the source folder... "

    # Munge build names throughout the entire source project (for all recursive deps)
    graphite_timer.start 'sed_replacements' do
        build_names_by_project.each do |dep_name, dep_build_name|
            string1 = "#{dep_name}\\/static\\/" 
            string2 = "#{dep_name}\\/#{dep_build_name}\\/" 

            sed_cmd = "find #{source_dir}/static-#{build_name} -type f -print0 | xargs -0 sed -i'.sedbak' 's/#{string1}/#{string2}/g'"
            puts sed_cmd

            unless system sed_cmd
                raise "Error munging build names for #{dep_name} to #{dep_build_name}"
            end

            system "find #{source_dir} -type f -name '*.sedbak' -print0 | xargs -0 rm"
        end
    end

    # Zip up the build-name-ified source
    source_archive_name = "#{static_project_name}-static-#{build_name}-src.tar.gz"
    system "cd #{source_dir}/..; tar cvzf #{source_archive_name} --exclude=.svn  --exclude=.git #{static_project_name}/"
    system "mv #{source_dir}/../#{source_archive_name} #{output_dir}"

    # Copy over the debug assets (wait till right before the upload to not goof up the hash checking)
    if building_debug_assets and Dir.exist?("#{debug_output_dir}/#{static_project_name}/static-#{build_name}")
        puts "\nCopying debug assets over to #{output_dir}/static-#{build_name}-debug\n"
        system "mv #{debug_output_dir}/#{static_project_name}/static-#{build_name} #{output_dir}/#{static_project_name}/static-#{build_name}-debug"

        # Change debug links from /static-x.y/ -> /static-x.y-debug/
        puts "\nPointing links in *.bundle-expanded.html to the debug folder"

        string1 = "\\/static-([0-9]+\\.[0-9]+)\\/"
        string2 = "\\/static-\\1-debug\\/"

        sed_cmd = "find #{output_dir}/#{static_project_name}/static-#{build_name} -type f -iname '*.bundle-expanded.html' -print0 | xargs -0 sed -i'.sedbak' -r 's/#{string1}/#{string2}/g'"

        # Macs use a different flag for extended regexes
        sed_cmd.sub!(' -r ', ' -E ') unless is_gnu

        puts sed_cmd

        graphite_timer.start 'debug_build_sed_replacements' do
            puts "Error munging build names from \"/static/\" to \'static-#{build_name}\". Continuing..." unless system sed_cmd
        end

        system "find #{output_dir}/#{static_project_name}/static-#{build_name} -type f -name '*.sedbak' -print0 | xargs -0 rm"
    end


    # upload the assets to S3 (too lazy to port to ruby at this point)
    puts "Uploading assets to s3...\n\n"
    cmd = "cd #{output_dir}; python26 #{jenkins_root}/hubspot_static_daemon/script/upload_project_assets_to_s3_parallel.py -p \"#{static_project_name}\" "

    graphite_timer.start 'uploading_to_s3' do
        raise "Error uploading static files to S3!" unless system cmd
    end

    puts "Invalidating QA scaffolds (so that QA gets the latest code immediately)..."

    cmd = "bash #{PYTHON_DEPLOY_STATIC_PATH} #{static_project_name}"
    puts "Running: #{cmd}"

    graphite_timer.start 'invalidate_static_scaffolds' do
        puts "Couldn't invalidate static scaffolds on QA, updates won't show up immediately." unless system cmd
    end

    puts "\n"
    return true
end

# The "dual" stopwatcher will track both "jenkins.static3.X" and "jenkins.static3.project_name.X" simultaneously
graphite_timer = DualGraphiteStopwatcher.new 'jenkins.static3.', "#{ENV['JOB_NAME']}."


graphite_timer.start 'total_build_duration' do
    begin
        build graphite_timer
    rescue StaticError => error
        puts "\nERROR during static3 build:\n"
        puts error, "\n"

        STDOUT.flush
        abort "Look above to see reason for build failure\n\n"
    rescue => error
        puts "\nUnknown ERROR during static3 build!\n"
        puts error, "\n"

        STDOUT.flush
        abort "Look above to see reason for build failure\n\n"
    end
end
