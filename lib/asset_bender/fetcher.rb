require 'typhoeus'

module AssetBender
  class Fetcher

    DEFAULT_OPTIONS = {
      :cache => false,
      :environment => :qa
    }

    def initialize(options)
      @options = DEFAULT_OPTIONS.merge options

      @has_cache = options[:cache]

      # Normalize the base domain
      @domain = options[:domain]
      @is_from_filesystem = @domain.start_with? "file://"
      @domain = "http://#{@domain}" if not @is_from_filesystem && @domain =~ /^https?:\/\//

      raise "Cache not yet implemented" if @has_cache
    end

    # Builds urls like:
    #
    #    http://thedomain.com/<project>/edge
    #    http://thedomain.com/<project>/recommended-qa
    #    http://thedomain.com/<project>/latest-version-2
    #    http://thedomain.com/<project>/latest-version-2.8-qa
    #
    def url_for_build_pointer(project_name, version, func_options = nil)
      func_options ||= {}
      raise "No need for a build url, version is already fixed (#{version})" unless version.is_wildcard

      if version.is_special_build_string
        version_pointer = version.to_s
      else
        version_prefix = version.non_wildcard_prefix
        version_pointer = "latest-version-#{version_prefix}"
      end

      if !func_options[:force_production] and @options[:environment] != :production
        version_pointer += "-qa" 
      end

      "#{@domain}/#{project_name}/#{version_pointer}"
    end

    def url_prefix_for_project_assets(project_name, build_version)
      "#{@domain}/#{project_name}/#{build_version}"
    end

    def strip_leading_slash(subpath)
      return subpath[1..-1] if subpath.start_with? '/'
      subpath
    end

    def build_asset_url(project_name, build_version, url_subpath)
      prefix = url_prefix_for_project_assets(project_name, build_version)
      url_subpath = strip_leading_slash url_subpath
      "#{prefix}/#{url_subpath}"
    end

    def build_hash_filename
      "premunged-static-contents-hash.md5"
    end

    def denormalized_dependencies_filename
      "prebuilt_recursive_static_conf.json"
    end

    def fetch_last_successful_build(project, func_options = nil)
      func_options ||= {}
      url = url_for_build_pointer project.name, project.version_to_build, func_options

      begin
        last_build = fetch_url_with_retries(url).strip
      rescue
        last_build = nil
      end

      if latest_build.nil? || latest_build.empty?
        logger.warn "Warning, can't fetch latest build for #{project_name} (version to build = #{version_to_build}). No latest link exists at: #{latest_build_url}"
        nil
      else
        last_build
      end
    end

    def fetch_last_production_build(project)
      fetch_last_successful_build project, { :force_production => true }
    end

    def fetch_last_build_hash(project)
      last_build_version = fetch_last_successful_build(project)
      url = build_asset_url project_name, last_build_version, build_hash_filename

      begin
        result = fetch_url_with_retries(url).strip
      rescue
        result = nil
      end

      if result.nil? || result.empty?
        logger.info "Couldn't fetch the build hash for #{project_name}. (Not too big of a deal)"
        nil
      else
        result
      end
    end

    def fetch_last_builds_dependencies(project)
      last_build_version = fetch_last_successful_build(project)
      url = build_asset_url project_name, last_build_version, denormalized_dependencies_filename

      begin
        result = fetch_url_with_retries(url).strip
        deps = JSON(json_string)['deps']
      rescue
        result = deps = nil
      end

      if result.nil? || deps.nil?
        logger.warning "Warning, can't fetch latest built dependencies. No #{denormalized_dependencies_filename} exists at: #{url} (or it is invalid)"
        nil
      else
        result
      end
    end

    def fetch_last_build_infomation(project)
      last_build_version = fetch_last_successful_build(project)

      config_url =             build_asset_url project_name, last_build_version, "component.json"
      denormalized_deps_url =  build_asset_url project_name, last_build_version, denormalized_dependencies_filename
      info_url =               build_asset_url project.name, last_build_version, "info.txt"

      begin
        config_result = fetch_url_with_retries(config_url)
        denormalized_deps_result = fetch_url_with_retries(denormalized_deps_url)
        info_result = fetch_url_with_retries(info_url)
      rescue; end

      if config_result.nil? or config_result.empty? or denormalized_deps_result.nil? or denormalized_deps_result.empty?
        logger.warning "Couldn't fetch current the last build information for #{project_name} (via #{static_conf_url} and #{prebuilt_conf_url})."
        nil
      else
        [config_result, denormalized_deps_result, info_result]
      end
    end

  end
end
