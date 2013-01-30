require "asset_bender/version_utils"
require "asset_bender/fetch_utils"
require "asset_bender/conf_utils"

module AssetBender
  VERSION = "0.1.0"

  autoload :Project,      "asset_bender/project"
  autoload :Version,      "asset_bender/version"
  # autoload :FetchUtils,        "asset_bender/fetch_utils"
  autoload :Fetcher,           "asset_bender/fetcher"
end
