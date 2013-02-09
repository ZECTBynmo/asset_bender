$: << './lib'
require 'asset_bender/server'

map '/' do
    run AssetBender::Server
end
