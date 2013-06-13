require "custom_singleton"
require "flexible_config"
require "string_inquirer"

module AssetBender
  VERSION = "0.1.0"

  class Error < StandardError; end

  require "asset_bender/version_utils"
  require "asset_bender/conf_utils"
  require "asset_bender/logger_utils"
  require "asset_bender/http_utils"
  require "asset_bender/proc_utils"
  require "asset_bender/update_archive_methods"

  def self.root
    File.expand_path(File.join(__FILE__, '../../'))
  end

  autoload :ProjectsManager,             "asset_bender/projects_manager"
  autoload :DependenciesManager,         "asset_bender/dependencies_manager"
  autoload :LocalArchive,                "asset_bender/local_archive"

  autoload :AbstractProject,             "asset_bender/project"
  autoload :AbstractFilesystemProject,   "asset_bender/filesystem_project"
  autoload :LocalProject,                "asset_bender/local_project"

  autoload :VersionMunger,               "asset_bender/version_munger"

  autoload :UnfulfilledDependency,       "asset_bender/unfulfilled_dependency"
  autoload :Dependency,                  "asset_bender/dependency"
  autoload :DependencyChain,             "asset_bender/dependency_chain"

  autoload :Version,                     "asset_bender/version"
  autoload :Fetcher,                     "asset_bender/fetcher"
  autoload :LocalFetcher,                "asset_bender/local_fetcher"
  autoload :Directory,                   "asset_bender/directory"

  autoload :TemplateHelpers,             "asset_bender/template_helpers"

  autoload :Config,                      "asset_bender/config"
  autoload :Setup,                       "asset_bender/setup"
end
