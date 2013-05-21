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

def convert_to_legacy_version(version)
  version.format AssetBender::Version::LEGACY_FORMAT_WITH_STATIC 
end

AssetBender::Config.project_config_fallback = lambda do |path|
  logger.info "Project has no component.json, falling back to the legacy static_conf.json"

  if File.exist? File.join path, "static_conf.json"
    static_conf = load_json_or_yaml_file File.join path, "static_conf.json"
  else
    static_conf = load_json_or_yaml_file File.join path, "static/static_conf.json"
  end

  result = {
    :name => static_conf[:name],
    :version => convert_to_asset_bender_version(static_conf[:major_version] || "1"),
  }

  if static_conf[:deps]
    result[:dependencies] = {}
    static_conf[:deps].each_with_object(result[:dependencies]) do |(dep, version), deps| 
      deps[dep] = convert_to_asset_bender_version version
    end
  end

  if static_conf[:major_version]
    result[:recommendedVersion] = convert_to_asset_bender_version static_conf[:major_version]
  end

  if static_conf[:build]
    built_version = AssetBender::Version.new "static-#{static_conf[:build]}"
    result[:version] = built_version.to_s
  end

  result
end

# Try the legacy "current" pointer if recommended doesn't work
AssetBender::Config.url_for_build_pointer_fallback = lambda do |project_name, version, func_options = nil|
  fetcher = func_options[:fetcher]

  if version.is_special_build_string? && version.to_s == 'recommended'
    version_pointer = "current"

  elsif version.is_wildcard?
    version_pointer = "latest-version-#{version.major}"
  end

  if version_pointer != 'edge' && !func_options[:force_production] && fetcher.options[:environment] != :production
    version_pointer += "-qa" 
  end 


  if fetcher.domain.start_with? "file://"
    domain = "file://#{File.join File.expand_path '~/.hubspot/static-archive/'}"
  else
    domain = fetcher.domain
  end

  "#{domain}/#{project_name}/#{version_pointer}"
end

AssetBender::Config.archive_url_fallback = lambda do |dep|
  archive_domain = AssetBender::Config.domain
  legacy_version = dep.version.to_legacy_hubspot_version

  "http://#{archive_domain}/#{dep.name}-#{legacy_version}-src.tar.gz"
end

# Convert the pointers and directory name in old archives to the new format
AssetBender::Config.modify_extracted_archive = lambda do |archive_path, dep, dep_pointers|
  dep_pointers.each do |pointer|
    existing_pointer_path = File.join archive_path, dep.name, pointer
    existing_pointer_content = File.read(existing_pointer_path).chomp
    is_old_style_pointer = existing_pointer_content.start_with? 'static-'

    next unless is_old_style_pointer

    new_pointer_filename = nil

    # Get rid of the old latested pointers (only keep the "edge" ones around)
    if ['latest', 'latest-qa'].include? pointer
      File.delete existing_pointer_path
      next

    # Convert "current" to "recommended"
    elsif pointer.start_with? 'current'
      new_pointer_filename = pointer.sub 'current', 'recommended'

    # Modify previous major pointers to the new style ("latest-version-x" -> "latest-version-0.x")
    elsif pointer.start_with? 'latest-version'
      new_pointer_filename = pointer.sub 'latest-version-', 'latest-version-0.'
    end

    # Delete the old pointer if it is going to be renamed
    if not new_pointer_filename.nil? and new_pointer_filename != pointer
      File.delete existing_pointer_path
    end

    # Write the new one
    new_pointer_filename ||= pointer
    new_pointer_path = File.join(archive_path, dep.name, new_pointer_filename)

    File.open new_pointer_path, 'w' do |f|
      new_version_style = AssetBender::Version.new(existing_pointer_content).url_format
      f.write "#{new_version_style}\n"
    end
  end

  # Move the actual archive folder
  legacy_version = dep.version.to_legacy_hubspot_version
  legacy_location = File.join archive_path, dep.name, legacy_version

  if Dir.exist? legacy_location
    FileUtils.mv legacy_location, File.join(archive_path, dep.name, dep.version.url_format)
  end
end


# Additional methods for Version instances

module AssetBender
  class Version

    # Convert a semver to the version system hubspot used to use, "static-x.y"
    def to_legacy_hubspot_version
      raise AssetBender::Error.new "Can only convert fixed versions to legacy hubspot version strings" if @semver.nil?
      logger.warn "Major versions other than 0 are lost in the legacy hubspot version conversion" if @semver.major > 0

      @semver.format AssetBender::Version::LEGACY_FORMAT_WITH_STATIC
    end

  end
end