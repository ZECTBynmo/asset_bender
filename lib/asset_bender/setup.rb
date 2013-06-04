
module AssetBender
  module Setup

    def self.setup_env(options = {})
      AssetBender::Config.mode = StringInquirer.new ENV['BENDER_ENV'] || options[:env] || "development"
      print "\n", "Running in #{AssetBender::Config.mode} mode", "\n\n"

      setup_temp_path
    end

    def self.setup_temp_path
      if AssetBender::Config.temp_path
        temp_path = Pathname temp_path
      else
        temp_path = Pathname File.expand_path('~/.bender-cache/')
      end

      if temp_path.relative?
        temp_path = Pathname("#{bender_root}/tmp/cache/").join temp_path
      end

      Config.temp_path = temp_path
    end

    # Sprockets config that is shared between the server and precompiling
    def self.setup_sprockets(options = {})
      sprockets = Sprockets::Environment.new(AssetBender.root, { :must_include_parent => true })

      sprockets.cache = Sprockets::Cache::FileStore.new sprockets_cache_path
      sprockets.logger.level = Logger::DEBUG

      if Config.mode.compressed?
        sprockets.js_compressor = :uglify
        sprockets.css_compressor = :yui
      end

      monkeypatch_directive_processors sprockets

      sprockets    
    end

    def self.sprockets_cache_path
      cache_path = Config.temp_path.join 'assets', Config.mode
      cache_path.to_s
    end

    def self.monkeypatch_directive_processors(sprockets)
      require "asset_bender/patches/hook_version_munging_into_sprockets"
      require "asset_bender/patches/hook_version_munging_into_sass_imports"

      # Replace the current js processor with our own:
      sprockets.unregister_processor('application/javascript', Sprockets::DirectiveProcessor)
      sprockets.register_processor('application/javascript', AssetBender::DirectiveProcessor)

      # Replace the current css processor with our own:
      sprockets.unregister_processor('text/css', Sprockets::DirectiveProcessor)
      sprockets.register_processor('text/css', AssetBender::DirectiveProcessor)

      sprockets.register_bundle_processor('application/javascript', AssetBender::DirectiveProcessor)
      sprockets.register_bundle_processor('text/css', AssetBender::DirectiveProcessor)

    end
  end

end
