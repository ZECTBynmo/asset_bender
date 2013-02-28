
# Copy some static config files to the project's module dir (if this is a python/django project). Necessary for django at runtime (and for the egg/venv install to do its thing correctly)
def copy_over_conf_to_python_module(static_project_name, static_workspace_dir, from_dir)
    python_module_dir = "#{static_workspace_dir}/#{static_project_name}"

    unless File.exist? "#{python_module_dir}/__init__.py"
        puts "\nWarning, no such #{python_module_dir} module folder, looking for the first subdirectory with an __init__.py"

        # Search for all directories that contain an __init__.py
        all_python_dirs = Dir.glob("#{static_workspace_dir}/*/").select { |folder| File.exist? File.join(folder, "__init__.py") }

        python_module_dir = all_python_dirs[0]
    end

    if python_module_dir
        puts "\nCopying static_conf.json and prebuilt_recursive_static_conf.json from #{from_dir} to #{python_module_dir}/static/ (so it will work via egg/venv install)"

        system "mkdir -p #{python_module_dir}/static"
        system "cp #{from_dir}/static_conf.json #{python_module_dir}/static/static_conf.json"
        system "cp #{from_dir}/prebuilt_recursive_static_conf.json #{python_module_dir}/static/prebuilt_recursive_static_conf.json"
        system "cp #{from_dir}/info.txt #{python_module_dir}/static/info.txt"
    else
        puts "\nAssuming this is not a python/django project, no module folder could be found."
    end
end


def download_previous_build_conf(static_project_name, major_version, to_dir)
    puts "\nDownloading static_conf.json, prebuilt_recursive_static_conf.json, and info.txt from the previous static build to shove into the python egg."
    prev_static_conf, prev_prebuilt_conf, prev_info_txt = StaticDependencies::fetch_latest_static_conf_prebuilt_conf_and_info_txt(static_project_name, major_version)

    print "\n", "Previous build static_conf.json:\n #{prev_static_conf}", "\n"
    print "\n", "Previous build prebuilt_recursive_static_conf.json:\n #{prev_prebuilt_conf}", "\n"
    print "\n", "Previous build info.txt:\n #{prev_info_txt}", "\n\n"

    File.open("#{to_dir}/static_conf.json", 'w') { |f| f.write prev_static_conf }
    File.open("#{to_dir}/prebuilt_recursive_static_conf.json", 'w') { |f| f.write prev_prebuilt_conf }
    File.open("#{to_dir}/info.txt", 'w') { |f| f.write prev_info_txt }
end
