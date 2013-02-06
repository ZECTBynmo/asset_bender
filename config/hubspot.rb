AssetBender::Config.register_extendable_base_config('base_hubspot_settings', {
  :domain => "hubspot-static2cdn.s3.amazonaws.com",
  :cdn_domain => "static2cdn.hubspot.com",

  :archive_dir => "~/.bender-archive/"
})

AssetBender::Config.set_brand_new_config_template("""# These base settings provides the global settings all hubspot projects
# require, such as the s3 domain, cdn domain, and default archive directory.
# (The contents come from asset_bender/config/hubspot.rb)

extends: base_hubspot_settings

# Local git repos you want the bender server to serve (can be
# overridden with command line arguments). Basically this should
# include all the projects you need to edit.
local_projects:
#  - ~/dev/src/bla
#  - ~/dev/src/somewhere/else/foobar

# port: 3333

# Preload style_guide bundle on startup (on by default)
# preload_style_guide_bundle: true

# Note, if you change this file you need to restart the bender server
""")