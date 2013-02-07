require 'bundler/setup'

require 'sinatra/base'

require 'sprockets'
require 'sprockets-sass'

require 'sass'
require 'compass'
require 'coffee-script'
require 'slim'

require 'asset_bender'
require 'asset_bender/server/directory_index'

Compass.configuration do |compass|

end


module AssetBender
  class ABServer < Sinatra::Base

    project_root = File.join settings.root, '../../'
    enable :logging

    set :slim, :pretty => true
    set :views, File.join(project_root, 'views')

    set :sprockets, Sprockets::Environment.new(root, { :must_include_parent => true })
    
    configure do
      internal_assets_path = File.join project_root, 'assets'
      State.setup Config.local_projects + [internal_assets_path], Config.local_archive

      State.available_projects.each do |project|
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
        :projects => AssetBender::State.available_projects.reject {|p| p.name == 'asset_bender_assets'}
      }
    end

    get '/bundle-?:verb?/:path' do
      is_extended = params[:extended]
      path = params[:path]
    end

    get '/*/' do
      project = project_from_url
      change_to_aliased_path_of project if path_matches_name_not_alias_from project

      index_generator = Server::DirectoryIndexGenerator.new project.parent_path, path
      index_generator.list_of_files_for_directory 
    end

    # Fall through to sprockets
    get '/*' do
      redirect_asset_if_needed

      project = project_from_url
      change_to_aliased_path_of project if path_matches_name_not_alias_from project

      ABServer.sprockets.call(env)
    end

    def get_path
      Rack::Utils.unescape(env['PATH_INFO'])
    end

    def project_from_url
      State.get_project_from_path get_path
    end

    def path_matches_name_not_alias_from project
      project.alias && get_path.start_with?("/#{project.name}")
    end

    def change_to_aliased_path_of project
      env['PATH_INFO'].sub! "/#{project.name}/", "/#{project.alias}/"
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
