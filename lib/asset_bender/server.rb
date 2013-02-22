require 'bundler/setup'

require 'sinatra/base'

require 'sprockets'
require 'sprockets-sass'

require 'sass'
require 'compass'
require 'coffee-script'
require 'slim'
require 'set'

require 'asset_bender'


Compass.configuration do |compass|
end

AssetBender::Config.load_all_base_config_files


module AssetBender
  class Server < Sinatra::Base

    project_root = File.join settings.root, '../../'
    enable :logging

    set :slim, :pretty => true
    set :views, File.join(project_root, 'views')

    set :sprockets, Sprockets::Environment.new(root, { :must_include_parent => true })
    
    configure do
      internal_assets_path = File.join project_root, 'assets'
      ProjectsManager.setup Config.local_projects + [internal_assets_path]
      DependenciesManager.setup Config.archive_dir

      ProjectsManager.available_projects.each do |project|
        sprockets.append_path project.path
      end
    end

    # error do
    #   slim :'errors/500'
    # end

    # not_found do
    #   slim :'errors/404'
    # end

    get '/' do
      slim :projects, :locals => {
        :projects => ProjectsManager.available_projects.reject {|p| p.name == 'asset_bender_assets'},
        :dependencies_by_version => DependenciesManager.available_dependencies_and_versions,
      }
    end

    get '/bundle-?:verb?/:path' do
      is_extended = params[:extended]
      path = params[:path]
    end

    get '/*/' do
      project_or_dependency = project_or_dependency_from_url
      change_to_aliased_path_of project if project_or_dependency.is_a?(AssetBender::LocalProject) && path_matches_name_not_alias_from(project_or_dependency)

      directory = AssetBender::Directory.new get_path, project_or_dependency

      if error = directory.check_forbidden or directory.check_directory_exists
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
      "/favicon.ico" => "/assets/favicon.png",
      "/favicon.png" => "/assets/favicon.png",
    }

    def redirect_asset_if_needed
      path = get_path 
      env['PATH_INFO'] = AssetRedirects[path] if AssetRedirects[path]
    end
  end
end
