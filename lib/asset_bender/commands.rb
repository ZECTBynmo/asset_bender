module AssetBender
  module Commands

    autoload :BaseCommand,         "asset_bender/commands/base_command"

    autoload :Run,                 "asset_bender/commands/run"
    autoload :Start,               "asset_bender/commands/start"
    autoload :Stop,                "asset_bender/commands/stop"
    autoload :Restart,             "asset_bender/commands/restart"

    autoload :Install,             "asset_bender/commands/install"
    autoload :UpdateDeps,          "asset_bender/commands/update_deps"

    autoload :Precompile,          "asset_bender/commands/precompile"
  end
end
