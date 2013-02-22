AssetBender::Config.register_extendable_base_config('base_hubspot_settings', {
  :domain => "hubspot-static2cdn.s3.amazonaws.com",
  :cdn_domain => "static2cdn.hubspot.com",

  :archive_dir => "~/.bender-archive/",
  :archive_url_prefix => "archive",

  # :allow_projects_without_component_json => true,
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

# project_to_preload:
#  - style_guide

# Note, if you change this file you need to restart the bender server
""")

include AssetBender::LoggerUtils
extend AssetBender::ConfLoaderUtils

def convert_to_asset_bender_version(version_string)
  version_string = version_string.to_s

  if version_string =~ /^\d+$/
    "0.#{version_string}.x"

  elsif version_string =~ /^\d+.\d+$/
    "0.#{version_string}"

  elsif version_string == 'current'
    'recommended'
  end
end

AssetBender::Config.project_config_fallback = lambda do |path|
  logger.info "Project has no component.json, falling back to the legacy static_conf.json"

  static_conf = load_json_or_yaml_file File.join path, "static/static_conf.json"

  result = {
    :name => static_conf[:name],
    :version => convert_to_asset_bender_version(static_conf['major_version'] || "1"),
  }

  if static_conf[:deps]
    result[:dependencies] = {}
    static_conf[:deps].each_with_object(result[:dependencies]) do |(dep, version), deps| 
      deps[dep] = convert_to_asset_bender_version version
    end
  end

  result
end


# Additional methods for Version instances

module AssetBender
  class Version

    # Convert a semver to the version system hubspot used to use, "static-x.y"
    def to_legacy_hubspot_version
      raise AssetBender::Error.new "Can only convert fixed versions to legacy hubspot version strings" if @semver.nil?
      logger.warn "Major versions other than 0 are lost in the legacy hubspot version conversion" if @semver.major > 0

      @semver.format "static-%m-%p"
    end

  end
end