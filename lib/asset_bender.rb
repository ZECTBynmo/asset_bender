# Early monkeypatches
require "asset_bender/patches/transform_hash_keys_to_symbols"

require "custom_singleton"

require "asset_bender/version_utils"
require "asset_bender/conf_utils"
require "asset_bender/logger_utils"
require "asset_bender/http_utils"
require "asset_bender/proc_utils"


module AssetBender
  VERSION = "0.1.0"

  extend LoggerUtils

  class Error < StandardError; end

  autoload :Project,           "asset_bender/project"
  autoload :LocalProject,      "asset_bender/local_project"
  autoload :Version,           "asset_bender/version"
  autoload :Fetcher,           "asset_bender/fetcher"
  autoload :Config,            "asset_bender/config"
  autoload :State,             "asset_bender/state"
  autoload :Directory,         "asset_bender/directory"
end
