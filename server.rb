# require 'bundler/setup'

require 'sinatra/base'
require 'sinatra/reloader'

require 'sprockets'
require "sprockets-sass"

require 'sass'
require 'compass'
require 'coffee-script'

Compass.configuration do |compass|
end

class AssetBenderServer < Sinatra::Base
  enable :logging

  set :sprockets, Sprockets::Environment.new(root, { :must_include_parent => true })
  
  configure do
    sprockets.append_path File.expand_path('~/dev/src/style_guide')
    sprockets.append_path File.expand_path('~/dev/src/common_assets')

    register Sinatra::Reloader
    also_reload File.join(root, 'server.rb')
    also_reload File.join(root, 'config.ru')
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

  # Fall through to sprockets
  get '/*' do
    AssetBenderServer.sprockets.call(env)
  end
end
