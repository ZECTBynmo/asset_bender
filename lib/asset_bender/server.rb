require 'bundler/setup'

require 'sinatra/base'

require 'sprockets'
require 'sprockets-sass'

require 'sass'
require 'compass'
require 'coffee-script'

require 'asset_bender'
require 'asset_bender/server/directory_index'

Compass.configuration do |compass|

end

module AssetBender
  class ABServer < Sinatra::Base
    include Server::DirectoryIndexGenerator

    enable :logging
    set :sprockets, Sprockets::Environment.new(root, { :must_include_parent => true })
    
    configure do
      State.setup Config.local_projects, Config.local_archive

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
      'Hello world!'
    end

    get '/bundle-?:verb?/:path' do
      is_extended = params[:extended]
      path = params[:path]
    end

    get '/*/' do
      print "\n", "directory index"
      path = Rack::Utils.unescape(env['PATH_INFO'])

      project = State.get_project_from_path path
      list_of_files_for_directory project.parent_path, path
    end

    # Fall through to sprockets
    get '/*' do
      ABServer.sprockets.call(env)
    end
  end
end
