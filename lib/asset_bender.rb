require "custom_singleton"
require "flexible_config"


module AssetBender
  VERSION = "0.1.0"

  class Error < StandardError; end

  require "asset_bender/version_utils"
  require "asset_bender/conf_utils"
  require "asset_bender/logger_utils"
  require "asset_bender/http_utils"
  require "asset_bender/proc_utils"

  autoload :ProjectsManager,             "asset_bender/projects_manager"
  autoload :DependenciesManager,         "asset_bender/dependencies_manager"
  autoload :LocalArchive,                "asset_bender/local_archive"

  autoload :AbstractProject,             "asset_bender/project"
  autoload :AbstractFilesystemProject,   "asset_bender/filesystem_project"
  autoload :LocalProject,                "asset_bender/local_project"
  autoload :Dependency,                  "asset_bender/dependency"

  autoload :Version,                     "asset_bender/version"
  autoload :Fetcher,                     "asset_bender/fetcher"
  autoload :Config,                      "asset_bender/config"
  autoload :Directory,                   "asset_bender/directory"
end
