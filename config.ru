$: << './lib'
require 'asset_bender/server'

map '/' do
    run AssetBender::ABServer
end
