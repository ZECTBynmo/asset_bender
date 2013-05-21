require 'json'

module AssetBender
  class Fetcher

    include HTTPUtils
    include LoggerUtils
    include ProcUtils

    DEFAULT_OPTIONS = {
      :cache => false,
      :environment => :qa,
      :domain => nil,
    }

    PULL_FROM_GLOBAL_CONFIG = [
      :environment,
      :domain,

      :build_hash_filename,
      :denormalized_dependencies_filename,
      :info_filename,
    ]

    attr_reader :options, :domain

    # Creates a new Fetcher instance, which is used to query your configured domain
    # for version numbers, build artifacts, etc. It is a class instead of methods
    # so you can share a  Fetcher object, and call fetch calls from it will be cached.
    def initialize(options = nil)
      options ||= {}

      # Start with the default settings
      @options = DEFAULT_OPTIONS.dup

      # Then pull in any global settings
      PULL_FROM_GLOBAL_CONFIG.each do |setting|
        @options[setting] = Config[setting] unless Config[setting].nil?
      end

      # Then use the passed in settings
      @options = @options.merge options
      
      @has_cache = @options[:cache]

      # Normalize the base domain
      @domain = @options[:domain] || ""
      @is_from_filesystem = @domain.start_with? "file://"
      @domain = "http://#{@domain}" if not @is_from_filesystem && @domain !=~ /^https?:\/\//

      raise AssetBender::Error.new "Cache not yet implemented" if @has_cache
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
      raise AssetBender::VersionError.new "No need for a build url, version is already fixed (#{version})" unless version.is_wildcard?

      if version.is_special_build_string?
        version_pointer = version.to_s

      elsif version.is_complete_wildcard
        version_pointer = 'edge'

      else
        version_prefix = version.non_wildcard_prefix
        version_pointer = "latest-version-#{version_prefix}"
      end

      if version_pointer != 'edge' && !func_options[:force_production] && @options[:environment] != :production
        version_pointer += "-qa" 
      end

      "#{@domain}/#{project_name}/#{version_pointer}"
    end

    # Helper for creating an asset URL
    def url_prefix_for_project_assets(project_name, build_version)
      "#{@domain}/#{project_name}/#{build_version}"
    end

    def strip_leading_slash(subpath)
      return subpath[1..-1] if subpath.start_with? '/'
      subpath
    end

    # The main way to create a URL to any asset served by asset bender
    def build_asset_url(project_name, build_version, url_subpath)
      prefix = url_prefix_for_project_assets(project_name, build_version)
      url_subpath = strip_leading_slash url_subpath
      "#{prefix}/#{url_subpath}"
    end

    # Filename that represents the hash created for a build. It is used to
    # compare during build time to see if the build in progress is any
    # different from the last successful one
    def build_hash_filename
      call_if_proc_otherwise_self @options[:build_hash_filename]
    end

    # Filename that represent the denormalized dependencies created for a 
    # project at build time. That means that it contains the exact version
    # of each dependnecy that was used in the build.
    def denormalized_dependencies_filename
      call_if_proc_otherwise_self @options[:denormalized_dependencies_filename]
    end

    def info_filename
      call_if_proc_otherwise_self @options[:info_filename]
    end

    def resolve_version_for_project(project_or_dep_name, version_wildcard, func_options = nil)
      version_string = fetch_build_for_project(project_or_dep_name, version_wildcard, func_options)

      raise AssetBender::Error.new "Couldn't resolve version for #{project_or_dep_name} #{version_wildcard}" unless version_string
      Version.new version_string
    end

    def fetch_build_for_project(project_or_dep_name, version_wildcard, func_options = nil)
      func_options ||= {}
      url = url_for_build_pointer project_or_dep_name, version_wildcard, func_options

      begin
        resolved_dep_version_string = fetch_url_with_retries(url).strip
      rescue
        logger.warn $!
        resolved_dep_version_string = nil
      end

      # Attempt the fallback url if it exists
      if not resolved_dep_version_string and not Config.url_for_build_pointer_fallback.nil?
        begin
          func_options[:fetcher] = self

          fallback_url = Config.url_for_build_pointer_fallback.call project_or_dep_name, version_wildcard, func_options

          if fallback_url && fallback_url == url
            logger.info "Skipping fallback url since it matches the regular url exactly"
          elsif fallback_url
            logger.info "Resolved version via fallback url: #{fallback_url}" 
            resolved_dep_version_string = fetch_url_with_retries(fallback_url).strip 
          end
        rescue
          logger.info "Error fetching via fallback url: #{fallback_url}" 
          logger.warn $!
          resolved_dep_version_string = nil
        end
      end

      if resolved_dep_version_string.nil? || resolved_dep_version_string.empty?
        logger.warn "Warning, can't resolve build for #{project_or_dep_name} (version = #{version_wildcard}). Nothing exists at: #{url}"
        nil
      else
        resolved_dep_version_string
      end
    end

    # Makes a HTTP request to your configured domain to figure out the last successful
    # build version for the passed project
    def fetch_last_build(project, func_options = nil)
      func_options ||= {}
      url = url_for_build_pointer project.name, project.version_to_build, func_options

      begin
        last_build = fetch_url_with_retries(url).strip
      rescue
        logger.warn $!
        last_build = nil
      end

      if last_build.nil? || last_build.empty?
        logger.warn "Warning, can't fetch latest build for #{project.name} (version to build = #{project.version_to_build}). No latest link exists at: #{url}"
        nil
      else
        last_build
      end
    end

    # Makes a HTTP request to your configured domain to figure out the last successful
    # production build version for the passed project
    def fetch_last_production_build(project)
      fetch_last_build project, { :force_production => true }
    end

    # Makes a HTTP request to your configured domain to grab the build hash 
    # for last successful build of the passed project. (Which can be used to detect if
    # a build has any new changes that need to be uploaded)
    def fetch_last_build_hash(project)
      last_build_version = fetch_last_build(project)
      url = build_asset_url project.name, last_build_version, build_hash_filename

      begin
        result = fetch_url_with_retries(url).strip
      rescue
        logger.warn $!
        result = nil
      end

      if result.nil? || result.empty?
        logger.info "Couldn't fetch the build hash for #{project.name}. (Not too big of a deal)"
        nil
      else
        result
      end
    end

    # Makes a HTTP request to your configured domain to grab the denormalized dependencies
    # for last successful build of the passed project. Retruns a dictionary of project name
    # to verions (AssetBender::Version instances).
    def fetch_last_builds_dependencies(project)
      last_build_version = fetch_last_build(project)
      url = build_asset_url project.name, last_build_version, denormalized_dependencies_filename

      begin
        json_string = fetch_url_with_retries(url).strip
        deps = JSON(json_string).each_with_object({}) do |(dep, version), obj|
          obj[dep] = AssetBender::Version.new version
        end
      rescue
        logger.warn $!
        json_string = deps = nil
      end

      if json_string.nil? || deps.nil?
        logger.warn "Warning, can't fetch latest built dependencies. No #{denormalized_dependencies_filename} exists at: #{url} (or it is invalid)"
        nil
      else
        deps
      end
    end

    # Makes a HTTP request to your configured domain to grab the last successful build's
    # component.json, denormalized deps, and info.txt (all as strings).
    #
    # (They are needed to shove into the python/node build artifacts if the current static build
    # has no changes and won't be uploaded)
    def fetch_last_build_infomation(project)
      last_build_version = fetch_last_build(project)

      config_url =             build_asset_url project.name, last_build_version, "component.json"
      denormalized_deps_url =  build_asset_url project.name, last_build_version, denormalized_dependencies_filename
      info_url =               build_asset_url project.name, last_build_version, info_filename

      begin
        config_result = fetch_url_with_retries(config_url)
        denormalized_deps_result = fetch_url_with_retries(denormalized_deps_url)
        info_result = fetch_url_with_retries(info_url)
      rescue
        logger.warn $!
      end

      if config_result.nil? or config_result.empty? or denormalized_deps_result.nil? or denormalized_deps_result.empty?
        logger.warning "Couldn't fetch current the last build information for #{project.name} (via #{static_conf_url} and #{prebuilt_conf_url})."
        nil
      else
        [config_result, denormalized_deps_result, info_result]
      end
    end


  end
end
