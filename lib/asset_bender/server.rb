require 'bundler/setup'

require 'sinatra/base'
require 'sinatra/sprockets-helpers'

require 'sprockets'
require 'sprockets-sass'
require 'sprockets-helpers'

require 'sass'
require 'compass'
require 'coffee-script'
require 'slim'
require 'set'

require 'asset_bender'
require 'asset_bender/patches/alias_sprocket_helpers'
require 'asset_bender/patches/fix_rack_livereload_with_cached_html'



Compass.configuration do |compass|
end

AssetBender::Config.load_all_base_config_files


module AssetBender
  class Server < Sinatra::Base
    register Sinatra::Sprockets::Helpers

    project_root = File.join settings.root, '../../'
    enable :logging

    set :slim, :pretty => true
    set :views, File.join(project_root, 'views')

    AssetBender::Setup.setup_env
    set :sprockets, AssetBender::Setup.setup_sprockets

    configure do
      # All of the images, css, etc that is used by asset bender UI
      internal_assets_path = File.join project_root, 'assets'

      ProjectsManager.setup((Config.local_projects || []) + [internal_assets_path])
      DependenciesManager.setup Config.archive_dir

      ProjectsManager.available_projects.each do |project|
        sprockets.append_path project.path
      end

      DependenciesManager.available_dependency_parent_paths.each do |path|
        sprockets.append_path path
      end

      configure_sprockets_helpers do |config|
        config.environment = sprockets
        config.prefix      = ""
        config.public_path = nil

        # Force to debug mode in development mode, but don't
        # use the :debug settings because that will overwrite asset_host
        config.expand = Config.mode.development?
        config.manifest = config.digest = !Config.mode.development?
        config.asset_host = Config.static_domain unless Config.static_domain.nil?
        config.protocol = :relative
      end

      # Helpers in ERB templates processed via sprockets
      sprockets.context_class.instance_eval do
        include AssetBender::TemplateHelpers
      end

    end

    helpers do
      include Sprockets::Helpers

    end

    if Config.livereload
      logger.info "Turning on rack-livereload"
      require 'rack-livereload'
      use Rack::LiveReload
    end

    # error do
    #   slim :'errors/500'
    # end

    # not_found do
    #   slim :'errors/404'
    # end

    get '/' do
      projects = ProjectsManager.available_projects.reject {|p| p.name == 'asset_bender_assets'}

      slim :projects, :locals => {
        :projects => projects,
        :dependencies_by_version => DependenciesManager.available_dependencies_and_versions,
        :dependencees_by_dep => DependenciesManager.dependees_by_dependency(projects),
      }
    end

    get '/bundle-?:verb?/:path' do
      is_extended = params[:extended]
      path = params[:path]

      # TODO
    end

    get '/*/' do
      project_or_dependency = project_or_dependency_from_url
      change_to_aliased_path_of project if project_or_dependency.is_a?(AssetBender::LocalProject) && path_matches_name_not_alias_from(project_or_dependency)

      directory = AssetBender::Directory.new get_path, project_or_dependency, Server.sprockets

      if error = directory.check_forbidden || directory.check_directory_exists
        logger.error error
        error
      else
        slim :directory, :locals => {
          :directory => directory
        }
      end
    end

    # Fall through to sprockets
    get '/*' do
      redirect_asset_if_needed

      project = project_from_url
      change_to_aliased_path_of project if path_matches_name_not_alias_from project

      Server.sprockets.call(env)
    end

    def get_path
      Rack::Utils.unescape(env['PATH_INFO'])
    end

    def project_from_url
      ProjectsManager.get_project_from_path get_path
    end

    def project_or_dependency_from_url
      get_project_or_dependency_from_path get_path
    end

    def path_matches_name_not_alias_from project
      project && project.alias && get_path.start_with?("/#{project.name}")
    end

    def change_to_aliased_path_of project
      env['PATH_INFO'].sub! "/#{project.name}/", "/#{project.alias}/"
    end

    def available_project_and_dependency_names
      Set.new ProjectsManager.served_projects.names + DependenciesManager.available_dependency_names
    end

    def get_project_or_dependency_from_path(url_or_path)
      result = ProjectsManager.get_project_from_path url_or_path
      result = DependenciesManager.get_dependency_from_path url_or_path unless result
      result
    end

    AssetRedirects = {
      "/favicon.ico" => "/assets/images/favicon.png",
      "/favicon.png" => "/assets/images/favicon.png",
    }

    def redirect_asset_if_needed
      path = get_path
      env['PATH_INFO'] = AssetRedirects[path] if AssetRedirects[path]
    end

    InternalAssetsToMaxAge = [
      "/assets/images/favicon.png",
      "/assets/images/favicon@2x.png",
    ]

    after do
      header_tweaks
    end

    def header_tweaks
      return unless response.headers

      # Add some max age caching to the favicons so they don't show up in the logs as much
      if InternalAssetsToMaxAge.include? env["PATH_INFO"]
        response.headers['Cache-control'] = "max-age=3600"
      end
    end
  end
end
