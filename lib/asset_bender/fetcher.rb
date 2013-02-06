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

      :build_hash_filename => "premunged-static-contents-hash.md5",
      :denormalized_dependencies_filename => "denormalized-deps.json",
      :info_filename => "info.txt",
    }

    PULL_FROM_GLOBAL_CONFIG = [
      :environment,
      :domain,

      :build_hash_filename,
      :denormalized_dependencies_filename,
      :info_filename,
    ]

    # Creates a new Fetcher instance, which is used to query your configured domain
    # for version numbers, build artifacts, etc. It is a class instead of methods
    # so you can share a  Fetcher object, and call fetch calls from it will be cached.
    def initialize(options = nil)
      options ||= {}
      @options = DEFAULT_OPTIONS.merge options

      PULL_FROM_GLOBAL_CONFIG.each do |setting|
        @options[setting] = Config[setting] unless Config[setting].nil?
      end

      print "\n", "options:  #{options.inspect}", "\n\n"

      @has_cache = @options[:cache]

      # Normalize the base domain
      @domain = @options[:domain]
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

    # Makes a HTTP request to your configured domain to figure out the last successful
    # build version for the passed project
    def fetch_last_successful_build(project, func_options = nil)
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
      fetch_last_successful_build project, { :force_production => true }
    end

    # Makes a HTTP request to your configured domain to grab the build hash 
    # for last successful build of the passed project. (Which can be used to detect if
    # a build has any new changes that need to be uploaded)
    def fetch_last_build_hash(project)
      last_build_version = fetch_last_successful_build(project)
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
      last_build_version = fetch_last_successful_build(project)
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
      last_build_version = fetch_last_successful_build(project)

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
