HubspotStaticDaemon::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable (err enable) Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Generate digests for assets URLs
  config.assets.digest = false

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Re-turn on auto_flushing for easier debugging (not in a stable release yet :/)
  # config.logger.auto_flushing = true

  # Turn off caching!
  config.cache_store = :memory_store
  config.action_controller.perform_caching = false

  # FORCE PRECOMPILED
  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false
end
