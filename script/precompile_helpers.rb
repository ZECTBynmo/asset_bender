def load_rails(env = 'compressed')
    # require File.expand_path('../../config/application', __FILE__)
    # require 'sprockets/directive_processor'

    ENV['RAILS_ENV'] = ENV['RAILS_ENV'] || env
    require File.expand_path(File.dirname(__FILE__) + "../../config/environment")

    require File.expand_path(File.dirname(__FILE__) + "../../lib/monkeypatch_sprockets_logical_path")

    require 'hubspot_helpers'
    include HubspotHelpers
    include ActionView::Helpers::AssetTagHelper

end

def target_directory
    target_variable = ENV['TARGET_STATIC_FOLDER']

    if target_variable
        target_variable
    else
        File.join(Rails.public_path, Rails.application.config.assets.prefix)
    end
end

# Cross-platform way of finding an executable in the $PATH.
#
#   which('ruby') #=> /usr/bin/ruby
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = "#{path}/#{cmd}#{ext}"
      return exe if File.executable? exe
    }
  end
  return nil
end

def precompile_project_assets
    load_rails

    _precompile_project()
end

def precompile_project_assets_and_munge_build_names
    load_rails

    _precompile_project()

    # The INGNORE_BUNDLE_DIRECTIVES environment variable needs to be set in order
    # to only compile file contents and skip all bundle generation (eg. ignore "//= require ....")
    #
    # Also, to ensure sure that bundles are correctly ignored, you'll need to clear the cache or
    # point to a different temp folder.
    
    if ENV['BUILD_NAMES']
        _replace_build_names()
    else
        print "\n", "Skipping build name munging.", "\n"
    end
end

def precompile_project_assets_plus
    load_rails

    _precompile_project()
    _build_bundle_files()

    if ENV['BUILD_NAMES']
        _replace_build_names()
    else
        print "\n", "Skipping build name munging.", "\n"
    end
end

def _precompile_project(compressed = nil)
    restrict_to = ENV['RESTRICT_TO']
    compressed = Rails.env.compressed? if compressed.nil?

    if compressed
        puts "\nCompiling, concatenating, and minifying...\n\n"
    else
        puts "\nCompiling and concatenating (no compression)...\n\n"
    end

    # Ensure the custom initializer (for the wrap_with_anonymous_function directive) is loaded 
    # require "#{Rails.root}/config/initializers/custom_bundle_directives.rb"

    # Ensure that action view is loaded and the appropriate
    # sprockets hooks get executed
    _ = ActionView::Base

    config = Rails.application.config
    config.assets.compile = true
    config.assets.compress = compressed
    config.assets.digest  = false
    config.assets.digests = {}

    env      = Rails.application.assets
    target   = target_directory
    compiler = Sprockets::StaticCompiler.new(env,
                                           target,
                                           config.assets.precompile,
                                           :manifest_path => config.assets.manifest,
                                           :digest => config.assets.digest,
                                           :manifest => true)

    begin
        compiler.compile
    rescue
        # Try and flush the output stream so that the error appears at the
        # bottom of the compiled output
        STDOUT.flush 

        raise
    end

    # Create the static folder just in case this project is empty
    system "mkdir -p #{target}/static"

    # We are not using pre-gzipped files right now, so delete them all
    puts "Deleting all the unecessary gzipped files..."
    system "find #{target} -name '*.gz' -print0 | xargs -0 rm"

    puts "Copying over extra static folders if needed (like font, ftl, etc)..."
    config.hubspot.static_project_paths.each do |src_path|
        project_name = src_path.split('/')[-1]

        Dir.chdir "#{src_path}/static"
        Dir.glob "*/" do |folder|
            folder.chomp! '/'

            if HubspotConfig::AdditionalStaticFolders.include? folder
                cmd = "cp -r #{src_path}/static/#{folder} #{target_directory}/#{project_name}/static"
                system cmd
            end
        end

        if restrict_to and restrict_to == project_name
            # Build a hash to compare future builds toward (and see if anything is different)

            if which('md5sum')
                md5_cmd = "md5sum"
            elsif which('md5')
                md5_cmd = "md5 -r"
            end

            if md5_cmd
                begin
                    md5_hash = `dir=#{target_directory}/#{project_name}/static; (find \"$dir\" -type f -exec #{md5_cmd} {} +; find \"$dir\" -type d) | LC_ALL=C sort | #{md5_cmd}`.chomp

                    puts "\nMD5 hash of contents: #{md5_hash}"

                    File.open("#{target_directory}/#{project_name}/static/premunged-static-contents-hash.md5", 'wb') do |f|
                        f.write md5_hash
                        f.close
                    end
                rescue
                    puts "Error building md5, is this an \"empty\" project?"
                end
            else
                puts "\nNeither md5sum or md5 present, no hash calculated."
            end
        end
    end
end

def _replace_build_names
    puts "\nMunging build names for cache-breakage\n"
    raise 'No BUILD_NAME env variable passed!' unless ENV['BUILD_NAMES']

    # Convert from <name>:<build>,<name2>:<build2>,...
    build_names = Hash[*ENV['BUILD_NAMES'].split(',').map {|x| x.split(':') }.flatten]
    restrict_to = ENV['RESTRICT_TO']
    target      = target_directory

    hubspot_config = Rails.application.config.hubspot

    Dir.chdir(target)

    projects = Set.new(hubspot_config.static_project_names)

    hubspot_config.static_project_names.each do |project_name|
        path = hubspot_config.served_projects_path_map[project_name] 
        static_deps = StaticDependencies::build_from_filesystem path, 'static', hubspot_config.only_use_production_builds

        projects.merge static_deps.projects_with_dependencies
    end

    # Do build name munging for each of the static projects
    projects.each do |project_name|
        build_name = build_names[project_name]
        build_name.gsub!('static-', '')
        
        raise "No build name was passed for #{project_name}!" unless build_name

        string1 = "#{project_name}\\/static\\/" 
        string2 = "#{project_name}\\/static-#{build_name}\\/" 

        puts "Replacing #{string1.gsub('\\', '')} with #{string2.gsub('\\', '')}"

        if restrict_to
            # Only search and replace in a single project
            search_dir = "#{restrict_to}/"
        else
            # Search and replace across all projects
            search_dir = '.'
        end

        # Deal with some BSD/GNU sed inplace funkiness
        system("find #{search_dir} -type f -print0 | xargs -0 sed -i'.sedbak' 's/#{string1}/#{string2}/g'")
        system("find #{search_dir} -type f -name '*.sedbak' -print0 | xargs -0 rm")

        if restrict_to and restrict_to == project_name
            system("if [ -d #{File.join(project_name, 'static-*')} ]; then echo 'Removing previous built static folder'; rm -r #{File.join(project_name, 'static-*')}; fi  ")

            puts "Moving #{File.join(project_name, 'static')} to #{File.join(project_name, 'static-' + build_name)}\n"
            system("mv #{File.join(project_name, 'static')} #{File.join(project_name, 'static-' + build_name)}")
        end
    end
end

def _build_bundle_files
    puts "\nGenerating bundle and bundle-expanded html...\n"

    restrict_to = ENV['RESTRICT_TO']
    static_project_path_re = Rails.application.config.hubspot.static_project_path_re
    limit_to_files = Rails.application.config.hubspot.limit_to_files

    # Build functions that will help filter down only the files that might be bundles we need to build

    # Ignores any filename that begins with '_' (e.g. sass partials) but includes 
    # all other css/js files in the provided static project folders that might be a bundle
    is_non_underscore_js_or_css_file = lambda { |path| path.end_with? "js", "css", "erb" and not File.basename(path).start_with? "_" }

    is_in_static_projects = lambda { |path| !!static_project_path_re.match(path) }

    is_in_restricted_project = lambda { |path| path.start_with?(restrict_to + '/static/') }

    # Temp hack for Patrick and content team
    ignore_sass_folder = !!ENV['DONT_COMPILE_SASS']
    is_ignored_sass_file = lambda { |path| not ignore_sass_folder or not path.include?('/sass/') }


    is_limited_file = lambda do |path|
        dir, filename = File.split path
        limit_to_files.include? filename
    end

    if restrict_to
        compile_asset = lambda do |path|
            is_non_underscore_js_or_css_file.call(path) and is_in_restricted_project.call(path) and (limit_to_files.empty? or is_limited_file.call(path)) and is_ignored_sass_file.call(path)
        end
    else
        compile_asset = lambda do |path|
            is_non_underscore_js_or_css_file.call(path) and is_in_static_projects.call(path) and (limit_to_files.empty? or is_limited_file.call(path)) and is_ignored_sass_file.call(path)
        end
    end


    # Ensure that action view is loaded and the appropriate
    # sprockets hooks get executed
    _ = ActionView::Base

    config = Rails.application.config
    config.assets.compile = true
    config.assets.compress = true
    config.assets.digest  = false
    config.assets.digests = {}

    env      = Rails.application.assets
    target   = target_directory
    compiler = Sprockets::StaticCompiler.new(env,
                                             target,
                                             [ compile_asset ],
                                             :manifest_path => config.assets.manifest,
                                             :digest => config.assets.digest,
                                             :manifest => false)


    # Iterate over every file in any of the asset paths (tons and tons of files that we might not care about)
    env.each_logical_path do |logical_path|

        # Check to see this file passes the above compile_asset Proc
        next unless compiler.compile_path?(logical_path)

        expanded_filename = File.join(target, logical_path) + ".bundle-expanded.html"
        bundle_filename = File.join(target, logical_path) + ".bundle.html"

        # If it loads and is a BundledAsset
        if asset = env.find_asset(logical_path) and asset.to_a.length > 1
            puts "Building bundle HTML for #{logical_path}"

            FileUtils.mkdir_p File.dirname(expanded_filename)

            # Ignore all of the recursive bundle deps
            non_bundle_deps = asset.to_a.map do |dep|
                dep unless dep.body.empty?
            end.compact

            expanded_html = non_bundle_deps.map { |dep|
                if is_js_bundle dep.pathname 
                    ActionController::Base.helpers.javascript_include_tag(dep.logical_path, { :body => false, :debug => false})
                elsif is_css_bundle dep.pathname
                    ActionController::Base.helpers.stylesheet_link_tag(dep.logical_path, { :body => false, :debug => false})
                end
            }.join("\n")

            File.open(expanded_filename, 'wb') do |f|
                f.write expanded_html
                f.close
            end


            if is_js_bundle asset.pathname 
                html = ActionController::Base.helpers.javascript_include_tag(asset.logical_path, { :body => false, :debug => false})
            elsif is_css_bundle asset.pathname
                html = ActionController::Base.helpers.stylesheet_link_tag(asset.logical_path, { :body => false, :debug => false})
            end

            File.open(bundle_filename, 'wb') do |f|
                f.write html
                f.close
            end

        # Non-bundled asset
        else
            File.open(bundle_filename, 'wb').close
            File.open(expanded_filename, 'wb').close
        end

    end
end
