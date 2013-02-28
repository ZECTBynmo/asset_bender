require 'json'
require 'fileutils'
require File.expand_path('../http_helpers',  __FILE__)

class StaticDependencyError < StandardError
end

STATIC_DEPS_FILENAME = 'static_conf.json'
PREBUILT_STATIC_DEPS_FILENAME = 'prebuilt_recursive_static_conf.json'
STATIC_DEPS_PROJECT_PATH = 'static'

DEFAULT_STATIC_DOMAIN = "hubspot-static2cdn.s3.amazonaws.com"

project_name_static_path_regex = /(?:\/|^)([^\/]+)\/static\//

# Extracts the project_name out of a path or URL that looks like any of these
# 
#     project_name/static/...
#     .../project_name/static/...
# 
# def extract_project_name_from_path(path_or_url)
#     match = project_name_static_path_regex.search(path_or_url)
#     Rails.application.config.hubspot.aliased_project_name(match.captures[0]) if match
# end

# def insert_build_name(path, build_name)
#     path.gsub('/static/', "/#{build_name}/")
# end

class String
  def is_integer?
    Integer(self) != nil rescue false
  end
end

# A class that parses and provides helper methods for static_conf.json (the file that lists
# the static dependencies for a project).
class StaticDependencies
    attr_reader :project_name, :major_version

    @@build_name_regex = /static-\d+\.\d+/

    class << self
      attr_accessor :deps_filename
    end
    self.deps_filename = STATIC_DEPS_FILENAME

    def initialize(json_string, only_use_production_builds = false)
        @json = JSON json_string
        @only_use_production_builds = only_use_production_builds

        @project_name = @json['name']
        raise StaticDependencyError, "You must specify a name in your #{self.deps_filename} file." unless @project_name

        @deps = @json['deps'] || {}
        @major_version = @json['major_version'] || 1

        clean_up_deps
    end

    def clean_up_deps
        @deps.each do |dep_name, dep_value|
            # Force major numbers like "2" to an int
            if dep_value.is_a?(String) and dep_value.is_integer?
                @deps[dep_name] = Integer(dep_value)
            end
        end
    end


    def project_dependency(project_name)
        dep = @deps[project_name]

        if dep.nil?
            puts "There is no static dependency for #{project_name} set in static_conf.json so automatically using 'current' build name."
            return 'current'
        elsif not is_valid_dependency_value(dep)
            raise StaticDependencyError, "Invalid static dependency set for the #{project_name} project: #{dep}"
        else
            return dep
        end
    end

    def projects_with_dependencies()
        @deps.map { |project, dep| project if is_valid_dependency_value(dep) }.compact
    end

    def all_project_dependencies()
        @deps.inject({}) do |result, (project, dep)|
            result[project] = dep if is_valid_dependency_value(dep)
            result
        end
    end

    def has_static_dependency(project_name)
        !!@deps[project_name]
    end

    def is_valid_build_name(build_name)
        @@build_name_regex.match(build_name.to_s)
    end

    def is_valid_dependency_value(dep)
        dep == "current" or dep == "latest" or dep == "edge" or dep.is_a? Fixnum or is_valid_build_name(dep)
    end

    # Parses the path, finds the project name, looks up the latest build name for that project (according
    # to static_conf.json), and inserts the build name into the path.
    # def insert_build_name_into_path(path, static_domain = nil)
    #     static_domain ||= DEFAULT_STATIC_DOMAIN
    #     project_name = extract_project_name_from_path(path)

    #     if not project_name
    #         raise StaticDependencyError, "Can't insert build name into path, can't find the project name (#{path})"
    #     end

    #     build_name_for_project = fetch_latest_static_build_name_for_project(project_name, static_domain)
    #     return insert_build_name(path, build_name_for_project)
    # end

    def self.url_for_latest_static_build_name(project_name, dep, static_domain = nil)
        static_domain ||= DEFAULT_STATIC_DOMAIN

        if static_domain.start_with? "file://"
            url = "#{static_domain}/#{project_name}/"
        else
            url = "http://#{static_domain}/#{project_name}/"
        end

        if dep == "current"
            url += "current"
        elsif dep == "latest"
            url += "latest"
        elsif dep == "edge"
            url += "edge"
        elsif dep.is_a?(Fixnum)
            url += "latest-version-#{dep}"
        else
            raise StaticDependencyError, "Unknown dependency, probably a bug in static_helpers."
        end

        # Default to using the qa bulid pointers unless only_use_production_builds is specified
        url += "-qa" unless @only_use_production_builds

        url
    end

    def fetch_latest_static_build_name_for_project(project_name, static_domain = nil)
        dep = project_dependency(project_name)

        # If an exact version is given, no fetch is necessary
        return dep if is_valid_build_name(dep)

        static_domain ||= DEFAULT_STATIC_DOMAIN
        error = false
        url = StaticDependencies::url_for_latest_static_build_name(project_name, dep, static_domain)

        begin
            result = fetch_url_with_retries(url)
        rescue
            puts $!.inspect, $@
            error = true
        end

        if error or result.nil? or result.empty?
            raise StaticDependencyError, "Couldn't fetch the static build name for #{project_name} (via #{url}). Either you haven't \"update-deps\" yet, something is wrong with your config, or the static servers are gone."
        end

        build_name = result.strip()
    end

    def fetch_all_latest_static_build_names_helper(static_domain = nil, fetched_results_cache = {})
        projects_with_dependencies().inject({}) do |results, project|
            if fetched_results_cache[project]
                results[project] = fetched_results_cache[project]
            else
                results[project] = fetch_latest_static_build_name_for_project(project, static_domain)
            end

            results
        end
    end

    def is_a_served_project?(served_projects_path_map, dep_project)
        # Is a project being served out of the local filesystem rather than the static archive
        !!served_projects_path_map and served_projects_path_map.include? dep_project
    end

    def fetch_static_deps_helper(dep_project, build_name_for_dep, static_domain = nil, options = {})
        is_a_served_project = is_a_served_project?(options[:served_projects_path_map], dep_project)

        if options[:local] and !is_a_served_project
            static_deps = self.class.build_from_filesystem "#{static_domain}/#{dep_project}", build_name_for_dep
        elsif options[:local]
            local_path = options[:served_projects_path_map][dep_project]
            static_deps = self.class.build_from_filesystem local_path
        else
            static_deps = self.class.build_from_url dep_project, build_name_for_dep, static_domain
        end

        static_deps
    end

    def fetch_all_latest_static_build_names(static_domain = nil, options = {})
        these_deps = fetch_all_latest_static_build_names_helper static_domain
    end

    def recursively_fetch_all_latest_static_build_names(static_domain = nil, options = {}, combined_results = {}, fetched_results_cache = {})
        # Right now this assumes that you have no circular static dependencies

        these_deps = fetch_all_latest_static_build_names_helper static_domain, fetched_results_cache
        fetched_results_cache.update these_deps

        combined_results[@project_name] ||= {}
        combined_results[@project_name].update(these_deps) { |key, v1, v2| v1 }

        unless these_deps.empty?
            non_fetched_projects = these_deps.keys.reject { |project| fetched_results_cache.include? project }

            non_fetched_projects.each do |dep_project|
                current_build_name_for_dep = combined_results[@project_name][dep_project]

                static_deps = fetch_static_deps_helper(dep_project, current_build_name_for_dep, static_domain, options)
                static_deps.recursively_fetch_all_latest_static_build_names static_domain, options, combined_results, fetched_results_cache

                # If this is a project served from the local static archive (unless :skip_self_build_names is set),
                # include a "self" build_name because it will be needed for munging later
                if not options[:skip_self_build_names] and not is_a_served_project?(options[:served_projects_path_map], dep_project)
                    combined_results[dep_project][dep_project] = current_build_name_for_dep
                end
            end
        else
            # print "Empty deps for #{@project_name}"
        end

        combined_results
    end

    def self.build_from_filesystem(project_directory, build_name = nil, only_use_production_builds = false)
        # Allow file:// urls
        project_directory.sub!("file://", "") if project_directory.start_with? "file://"

        project_directory = File.expand_path project_directory
        static_dir = build_name || STATIC_DEPS_PROJECT_PATH 

        path = File.join(project_directory, static_dir, self.deps_filename)

        begin
            File.open path, 'r' do |deps_file|
                return self.new deps_file.read(), only_use_production_builds
            end
        rescue Errno::ENOENT
            puts "This project doesn't have a static_conf.json file, looking for it at: #{path}"
            return self.new "{}", only_use_production_builds
        end
    end

    def self.build_from_url(project, build_name, static_domain = nil)
        static_domain ||= DEFAULT_STATIC_DOMAIN
        url = "http://#{static_domain}/#{project}/#{build_name}/#{self.deps_filename}"

        begin
            self.new fetch_url_with_retries url
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError
            puts $!.inspect, $@
            puts "This project doesn't have a #{self.deps_filename} file, looking for it at: #{url}"
            return self.new "{}"
        end
    end

    def self.build_from_string(deps_file_string)
        return self.new deps_file_string
    end

    def create_static_deps_file_with_build(destination, current_build_name)
        destination = File.expand_path destination
        json = @json.clone
        json[:build] = current_build_name
        json = JSON.pretty_generate json

        puts "Create static_conf.json with build info: ", json

        # Ensure directory exists
        FileUtils.mkdir_p File.split(destination)[0]

        File.open destination, 'w' do |f|
          f.write json
        end
    end

    def self.create_fixed_static_deps_file(destination, project_name, current_build_name, deps)
        destination = File.expand_path destination
        json = JSON.pretty_generate({
            :name  => project_name,
            :build => current_build_name,
            :deps  => deps || {}
        })

        puts "Creating fixed static_conf.json: ", json

        # Ensure directory exists
        FileUtils.mkdir_p File.split(destination)[0]

        File.open destination, 'w' do |f|
          f.write json
        end
    end

    def self.create_recursive_fixed_static_deps_file(destination, project_name, current_build_name, all_deps)
        self.create_fixed_static_deps_file destination, project_name, current_build_name, all_deps
    end

    def self.fetch_latest_build(project_name, major_version = 1, static_domain = nil, force_production = false)
        static_domain ||= DEFAULT_STATIC_DOMAIN
        error = false

        if major_version.nil? || major_version == 'edge' || major_version == 'latest' 
            pointer = "edge-qa"
        else
            pointer = "latest-version-#{major_version}"
        end

        latest_build_url = "http://#{static_domain}/#{project_name}/#{pointer}"
        latest_build_url += "-qa" if not @only_use_production_builds and not force_production

        begin
            latest_build = fetch_url_with_retries(latest_build_url).strip
        rescue
            puts $!.inspect, $@
            error = true
        end

        if error or latest_build.nil? or latest_build.empty?
            print "Warning, can't fetch latest build for #{project_name} (major version = #{major_version}). No latest link exists at: #{latest_build_url}"
            return nil
        end

        latest_build
    end

    def self.fetch_latest_production_build(project_name, major_version = 1)
        self.fetch_latest_build(project_name, major_version, nil, true)
    end

    def self.fetch_latest_built_md5_for_project(project_name, major_version = 1, static_domain = nil)
        static_domain ||= DEFAULT_STATIC_DOMAIN
        error = false

        latest_build = self.fetch_latest_build(project_name, major_version)
        url = "http://#{static_domain}/#{project_name}/#{latest_build}/premunged-static-contents-hash.md5"

        begin
            result = fetch_url_with_retries(url)
        rescue
            puts $!.inspect, $@
            error = true
        end

        if error or result.nil? or result.empty?
            # raise StaticDependencyError, "Couldn't fetch the md5 for #{project_name} (via #{url}). Either something is wrong with your config or the static servers are gone."
            return nil
        end

        result.strip()
    end

    def self.fetch_latest_built_dependencies(project_name, major_version = 1, static_domain = nil)
        static_domain ||= DEFAULT_STATIC_DOMAIN
        error = false

        latest_build = self.fetch_latest_build(project_name, major_version)
        url = "http://#{static_domain}/#{project_name}/#{latest_build}/prebuilt_recursive_static_conf.json"

        begin
            json_string = fetch_url_with_retries(url)
        rescue
            puts $!.inspect, $@
            error = true
        end

        if error or json_string.nil? or json_string.empty?
            print "Warning, can't fetch latest built dependencies. No prebuilt_recursive_static_conf.json exists at: #{url}"
            return nil
        end

        json = JSON json_string
        return json['deps']
    end

    def self.fetch_latest_static_conf_prebuilt_conf_and_info_txt(project_name, major_version = 1, static_domain = nil)
        static_domain ||= DEFAULT_STATIC_DOMAIN
        error = false

        latest_build = self.fetch_latest_build(project_name, major_version)
        static_conf_url = "http://#{static_domain}/#{project_name}/#{latest_build}/static_conf.json"
        prebuilt_conf_url = "http://#{static_domain}/#{project_name}/#{latest_build}/prebuilt_recursive_static_conf.json"
        info_url = "http://#{static_domain}/#{project_name}/#{latest_build}/info.txt"

        begin
            static_conf_result = fetch_url_with_retries(static_conf_url)
            prebuilt_conf_result = fetch_url_with_retries(prebuilt_conf_url)
            info_result = fetch_url_with_retries(info_url)
        rescue
            puts $!.inspect, $@
            error = true
        end

        if error or static_conf_result.nil? or static_conf_result.empty? or prebuilt_conf_result.nil? or  prebuilt_conf_result.empty?
            raise StaticDependencyError, "Couldn't fetch current static conf for #{project_name} (via #{static_conf_url} and #{prebuilt_conf_url}). Either something is wrong with your config or the static servers are gone."
        end

        [static_conf_result, prebuilt_conf_result, info_result]
    end


    # Implementation of <=> for build names. So:
    #
    # >>> compare_build_names 'static-1.0', 'static-1.1'
    # -1
    # >>> compare_build_names 'static-2.0', 'static-1.1'
    # 1
    # >>> compare_build_names 'static-3.4', 'static-3.4'
    # 0
    def self.compare_build_names(x_build, y_build)
        # Convert each build name to a two element tuple
        x, y = [x_build, y_build].map do |build|
            build.chomp.gsub!('static-', '').split('.').map { |str| str.to_i }
        end

        major_cmp = x[0] <=> y[0]

        return major_cmp unless major_cmp == 0
        x[1] <=> y[1]
    end

end

class PrebuiltStaticDependencies < StaticDependencies
    class << self
      attr_accessor :deps_filename
    end
    self.deps_filename = PREBUILT_STATIC_DEPS_FILENAME

    def fetch_all_latest_static_build_names_helper(static_domain = nil, projects_to_ignore = [])
        # No need to fetch, these were prebuilt!
        @deps
    end
end

# Some quick and dirty testing
if __FILE__ == $0
  $:.unshift File.join(File.dirname(__FILE__),'..')

  # static_deps = StaticDependencies::build_from_filesystem "~/dev/hubspot/github/style_guide"
  static_deps = StaticDependencies::build_from_filesystem "~/dev/hubspot/github/example_web_static_v3/"

  puts "\nname:  #{static_deps.project_name.inspect}\n\n"
  
  all_deps = static_deps.projects_with_dependencies
  puts "\nall_deps:  #{all_deps.inspect}\n\n"

  all_build_names = static_deps.fetch_all_latest_static_build_names_helper
  puts "\nall_build_names:  #{all_build_names.inspect}\n\n"

  # StaticDependencies::create_fixed_static_deps_file "/tmp/static_deps_test.json", static_deps.project_name, all_build_names

  # recursive_build_names = static_deps.recursively_fetch_all_latest_static_build_names
  # puts "\nrecursive_build_names:  #{recursive_build_names.inspect}\n\n"

  # StaticDependencies::create_recursive_fixed_static_deps_file "/tmp/recursive_static_deps_test.json", static_deps.project_name, recursive_build_names

  md5_hash = StaticDependencies::fetch_latest_built_md5_for_project "example_web_static_v3"
  puts "\nmd5_hash:  #{md5_hash.inspect}\n\n"

  latest_built_deps = StaticDependencies::fetch_latest_built_dependencies "example_web_static_v3"
  print "\n", "latest_built_deps:  #{latest_built_deps.inspect}", "\n\n"

  a, b, c = StaticDependencies::fetch_latest_static_conf_prebuilt_conf_and_info_txt "example_web_static_v3"
  print "\n", "static_conf.json:  #{a.inspect}", "\n\n"
  print "\n", "prebuilt_recursive_static_conf.json:  #{b.inspect}", "\n\n"
  print "\n", "info.txt:  #{c.inspect}", "\n\n"
end
