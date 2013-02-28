require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "active_resource/railtie"
require "sprockets/railtie"
require 'rack/cache'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module HubspotStaticDaemon
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.autoload_paths += Dir["#{config.root}/lib", "#{config.root}/lib/**/"]

    # HubSpot specific configuration
    require "#{config.root}/lib/hubspot_config.rb"
    hubspot_config = HubspotConfig.new

    # TMP dir messin'
    # (also in config/initializers/move_sass_tmp_dir.rb)
    if hubspot_config.custom_temp_dir
      config.cache_store = [ :file_store, "#{hubspot_config.custom_temp_dir}/cache/" ]
      config.assets.cache_store = [ :file_store, "#{hubspot_config.custom_temp_dir}/cache/assets/" ]
    end

    # Allow custom setting of SASS import and image paths
    if ENV['COMPASS_IMPORT_PATHS']
      puts "Using sass import paths.."
      ENV['COMPASS_IMPORT_PATHS'].split(":").each { |path| config.compass.add_import_path path }
    end
    if ENV['COMPASS_IMAGE_PATH']
      config.compass.images_path = ENV['COMPASS_IMAGE_PATH']
    end

    # HUBSPOT STUFF VIA ~/.hubspot/config
    if Rails.env.precompiled? and ENV['TARGET_STATIC_FOLDER']

      target_precompiled_folder = File.expand_path(ENV['TARGET_STATIC_FOLDER'])
      config.assets.paths = [ target_precompiled_folder ]
      puts "Watching the precompiled target folder: #{target_precompiled_folder}", "\n"

    elsif Rails.env.precompiled?
      raise "You must specify a TARGET_STATIC_FOLDER when using FORCE_PRECOMPILED"

    # Add all of the asset folders (js, coffee, sass, etc) found in the provided static project folders
    elsif hubspot_config.static_project_parents
      # Ensure that the deepest paths are specified first (to prevent recursive path issues)
      parent_paths_sorted_by_depth = hubspot_config.static_project_parents.sort do |a, b|
        b.count(File::SEPARATOR) <=> a.count(File::SEPARATOR)
      end

      config.assets.paths += parent_paths_sorted_by_depth
      config.compass.sprite_load_path += hubspot_config.static_project_parents

      puts "\nWatching all of these HubSpot projects: ", hubspot_config.static_project_paths.to_a, "\n" unless hubspot_config.static_project_paths.empty?
      puts "Watching all of these static dependencies: ", hubspot_config.static_dependency_paths.to_a, "\n" unless hubspot_config.static_dependency_paths.empty?
    end

    # Store stuff for potential future usage
    config.hubspot = hubspot_config

    static_project_path_re = hubspot_config.static_project_path_re
    limit_to_files = hubspot_config.limit_to_files

    # Temp hack for Patrick and content team
    ignore_sass_folder = !!ENV['DONT_COMPILE_SASS']
    is_ignored_sass_file = lambda { |path| not ignore_sass_folder or not path.include?('/sass/') }

    # Ignores any filename that begins with '_' (e.g. sass partials) but includes 
    # all other css/js/sass/image files that are in in the provided static project folders
    is_an_asset = lambda { |path| path.end_with?("js", "css", "png", "gif", "jpg", "html", "handlebars", "swf", "json") and not File.basename(path).start_with?("_") }

    is_in_static_projects = lambda { |path| config.hubspot.static_project_path_re.match(path) }

    is_in_restricted_project = lambda { |path| path.start_with?(hubspot_config.restrict_precompilation_to + '/static/') }

    is_not_limited_file = lambda do |path|
      return true if limit_to_files.empty?

      dir, filename = File.split path
      limit_to_files.include? filename
    end

    if hubspot_config.restrict_precompilation_to
      puts "Restricting precompilation to #{hubspot_config.restrict_precompilation_to}"

      func = lambda do |path|
        if is_an_asset.call(path) and is_in_restricted_project.call(path) and is_not_limited_file.call(path) and is_ignored_sass_file.call(path)
          puts "Compiling: #{path}"
          true
        else
          false
        end
      end

      config.assets.precompile = [ func ]
    else
      func = lambda do |path|
        if is_an_asset.call(path) and is_in_static_projects.call(path) and is_not_limited_file.call(path) and is_ignored_sass_file.call(path)
          puts "Compiling: #{path}"
          true
        else
          false
        end
      end

      config.assets.precompile = [ func ]
    end

    config.assets.prefix = ''

    # Our static assets should not be depending on rails controllers and such (only helper methods)
    config.assets.initialize_on_precompile = false

    # No caching plz
    config.middleware.delete Rack::Cache

    config.dev_tweaks.log_autoload_notice = false
  end

end
