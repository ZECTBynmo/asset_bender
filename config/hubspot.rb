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

  else
    version_string
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

  if File.exist? File.join path, "prebuilt_recursive_static_conf.json"
    prebuilt_static_conf = load_json_or_yaml_file File.join path, "prebuilt_recursive_static_conf.json"
  elsif File.exist? File.join path, "prebuilt_recursive_static_conf.json"
    prebuilt_static_conf = load_json_or_yaml_file File.join path, "static/prebuilt_recursive_static_conf.json"
  else
    prebuilt_static_conf = nil
  end

  result = {
    :name => static_conf[:name],
    :version => convert_to_asset_bender_version(static_conf[:major_version] || "1"),
    :legacy => true
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

  # If this is a prebuilt src archive or prebuilt_recursive_static_conf.json
  if prebuilt_static_conf
    # Move all prebuilt deps to fixed_dependencies 
    result[:fixed_dependencies] = prebuilt_static_conf[:deps]
  end

  result
end

# Try the legacy "current" pointer if recommended doesn't work
AssetBender::Config.url_for_build_pointer_fallback = lambda do |project_name, version, func_options = nil|
  fetcher = func_options[:fetcher]

  if version.is_special_build_string? && version.to_s == 'recommended'
    version_pointer = "current"

  elsif version.is_wildcard?
    version_pointer = "latest-version-#{version.minor}"
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

AssetBender::Config.dependency_path = lambda do |root_path, dependency_name, version|
  print "\n", "version:  #{version.inspect}", "\n\n"

  normal_path = File.join root_path, dependency_name.to_s, version.path_format
  legacy_path = File.join root_path, dependency_name.to_s, version.to_legacy_hubspot_version

  if Dir.exist? normal_path
    normal_path
  else
    logger.info "Falling back to legacy depdency path: #{legacy_path}"
    legacy_path
  end
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

    # Delete the old pointer if it needs a new name
    if not new_pointer_filename.nil? and new_pointer_filename != pointer
      File.delete existing_pointer_path

      # Write the new one
      new_pointer_filename ||= pointer
      new_pointer_path = File.join(archive_path, dep.name, new_pointer_filename)

      File.open new_pointer_path, 'w' do |f|
        f.write "#{existing_pointer_content}\n"
      end
    end
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


# Tweaks to the dependency class

module AssetBender
  class Dependency

    def is_legacy?
      @config[:legacy]
    end


  end
end