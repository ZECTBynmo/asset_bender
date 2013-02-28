require 'set'
require 'yaml'

require File.expand_path('../local_static_archive',  __FILE__)

class HubspotConfig
  attr_accessor :port, :static_project_paths, :static_project_names, :static_project_parents,
                :restrict_precompilation_to, :static_dependency_names, :static_dependency_paths,
                :preload_style_guide_bundle, :running_server_from_script, :old_static_domain, :limit_to_files,
                :local_static_archive, :dependencies_for, :archive_dir, :static_projects_with_views,
                :static_project_view_paths, :only_use_production_builds, :served_projects_path_map,
                :custom_temp_dir, :static_projects_with_specs, :static_projects_spec_paths,
                :served_dependency_path_map

  StaticAssetTypes = ['js', 'coffee', 'css', 'sass', 'scss', 'img', 'html', 'test']

  # All the other kinds of static folders that we need to ensure are uploaded to s3,
  # so add to this as more are necessary (don't add the css, sass, js dirs; it would
  # clobber the compiled output)
  AdditionalStaticFolders = ['ftl', 'font']

  def initialize(runtime_options=nil)
    @runtime_options = runtime_options

    @valid_project_folders = []
    @static_project_paths = Set.new
    @static_project_names = Set.new
    @served_projects_path_map = {}
    @static_dependency_paths = Set.new
    @static_dependency_names = Set.new
    @served_dependency_path_map = {}
    @static_projects_with_views = Set.new
    @static_project_view_paths = Set.new
    @static_projects_with_specs = Set.new
    @static_projects_spec_paths = Set.new
    @archive_dir = File.join config_directory, "static-archive/"
    @custom_temp_dir = nil

    @project_aliases = {}
    @dependencies_for = {}

    @only_use_production_builds = false

    load
  end

  def load
    check_if_directory_exists
    check_if_config_file_exists

    # Defaults

    @preload_style_guide_bundle = true
    @live_reload = false
    @old_static_server = ''
    @port = 3333
    @limit_to_files = []

    # Parse ~/.hubspot/config and pull out basic keys

    @config = YAML.load_file(config_file)
    @config = {} unless @config
    grab_from_json :restrict_precompilation_to, :preload_style_guide_bundle, :old_static_server, :port,
                   :live_reload, :archive_dir, :only_use_production_builds

    # Runtime overloads

    if @runtime_options
      @config['static_projects'] = @runtime_options[:static_projects] if @runtime_options[:static_projects]
      @archive_dir = @runtime_options[:archive_dir] if @runtime_options[:archive_dir]
    end


    # Overloading environment variables (the ones needed before parsing projects)

    if ENV['HUBSPOT_STATIC_PROJECTS']
      @config['static_projects'] = ENV['HUBSPOT_STATIC_PROJECTS'].split(',').map { |proj| proj.strip }
    end

    if ENV['ARCHIVE_DIR']
      @archive_dir = ENV['ARCHIVE_DIR']
    end

    if ENV['PROD_BUILDS_ONLY']
      @only_use_production_builds = true
    end

    if ENV['CUSTOM_TEMP_DIR']
      @custom_temp_dir = ENV['CUSTOM_TEMP_DIR']
    end

    if ENV['PORT']
      @port = ENV['PORT']
    end

    # Force a different temp directory when ignoring bundles (since our hack prevents the cache from
    # noticing the difference)
    if ENV['INGNORE_BUNDLE_DIRECTIVES'] 
      @custom_temp_dir = Rails.application.config.cache_store[1].sub!(/\/cache\/$/, '') unless @custom_temp_dir
      @custom_temp_dir += "-ignoring-bundles"
    end

    # Build rest of config from inputs

    @valid_project_folders = find_valid_static_folders(@config['static_projects'])

    @local_static_archive = LocalStaticArchive.new @archive_dir
    @valid_dependency_folders = find_valid_static_folders(@local_static_archive.projects_in_archive)

    search_for_projects_with_assets_or_views
    search_for_dependencies_with_assets_or_views

    @static_project_parents = extact_parent_folders @static_project_paths + @static_dependency_paths


    unless ENV['SKIP_GATHERING_LOCAL_BUILD_NAMES']
      gather_dependent_build_names 
    end

    # Overloading the other environment variables

    if ENV['RESTRICT_TO']
      @restrict_precompilation_to = ENV['RESTRICT_TO']
    end

    if ENV['RUN_FROM_SCRIPT']
      @running_server_from_script = true
    end

    if ENV['LIMIT_TO']
      @limit_to_files = ENV['LIMIT_TO'].split(',')
    end

    if ENV['EXTRA_CONFIG']
      @extra_hash = eval(ENV['EXTRA_CONFIG']) or {}
    else
      @extra_hash = {}
    end

    def method_missing(meth, *args, &block) 
      @extra_hash[meth]
    end

  end

  def grab_from_json(*keys)
    keys.each do |key|
      self.instance_variable_set("@#{key}".to_sym, @config[key.to_s]) if @config[key.to_s]
    end
  end

  # def save
  #   File.open config_file do |f|
  #     f.write @config.to_yaml
  #   end
  # end

  def check_if_directory_exists
    if not File.directory? config_directory
      puts "You, don't have a ~/.hubspot directory, creating it\n" 
      puts "That probably also means that you haven't run './hs-static update-deps -p <path-to-your-projects' yet, either (which you should do).\n"

      Dir::mkdir config_directory
    end
  end

  def check_if_config_file_exists
    if not File.exists? config_file
      puts "You, don't have a ~/.hubspot/config.yaml file, creating it"
      file = File.new(config_file, 'w')
      file.write """
# A list of all the current static projects you are working on
static_projects:
  - ~/dev/hubspot/python/django_projects/example_web

# Port for the static daemon to run on (3333 by default)
# port: 3333

# Preload style_guide bundle on startup (on by default)
# preload_style_guide_bundle: true

      """
      file.close()
    end
  end

  def config_directory
    File.expand_path "~/.hubspot"
  end

  def config_file
    File.expand_path "#{config_directory}/config.yaml"
  end

  def find_valid_static_folders(folders)
    return [] unless folders

    folders = folders.map do |project|
      project = File.expand_path project

      if File.directory? project
        project
      else
        puts "Warning: there is no such directory #{project}"
      end
    end.compact
  end

  def folders_with_static_directories(input_folders) 
    folders = input_folders.map do |project|
      begin
        static_dir = Dir.glob("#{project}/static*")[0]
        project if File.exists? "#{static_dir}/static_conf.json"
      rescue
        puts "Warning: there is no static/static_conf.json file inside #{project}"
      end
    end

    folders.compact
  end

  def folders_with_spec_directories(input_folders)
    input_folders.map do |project|
      spec_dir = "#{project}/static/test/spec"
      project if File.directory? spec_dir
    end.compact
  end

  def folders_with_view_directories(input_folders)
    input_folders.map do |project|
      view_dir = "#{project}/view"
      project if File.directory? view_dir
    end.compact
  end

  def search_for_projects_with_assets_or_views
    folders_with_static_directories(@valid_project_folders).each do |project|
        add_to_actual_static_project_set project
    end

    folders_with_view_directories(@valid_project_folders).map do |project|
        add_to_actual_static_project_set project
        add_to_projects_with_views project
    end

    folders_with_spec_directories(@valid_project_folders).each do |project|
        add_to_projects_with_specs project
    end

  end

  def search_for_dependencies_with_assets_or_views
    folders_with_static_directories(@valid_dependency_folders).each do |project|
        add_to_static_dependencies project
    end

    folders_with_view_directories(@valid_dependency_folders).map do |project|
        add_to_static_dependencies project
        add_to_projects_with_views project
    end
  end

  def add_to_actual_static_project_set(project)
    name = project.split('/')[-1]

    @static_project_paths.add project
    @static_project_names.add name
    @served_projects_path_map[name] = project
  end

  def add_to_static_dependencies(project)
    name = project.split('/')[-1]

    unless @static_project_names.include? name
      @static_dependency_paths.add project
      @static_dependency_names.add name
      @served_dependency_path_map[name] = project
    end
  end

  def add_to_projects_with_views(path)
    @static_projects_with_views.add path.split('/')[-1]
    @static_project_view_paths.add "#{path}/view"
  end

  def add_to_projects_with_specs(path)
    @static_projects_with_specs.add path.split('/')[-1]
    @static_projects_spec_paths.add "#{path}/static/test/spec"
  end


  def extact_parent_folders(folders)
    parent_folders = Set.new

    folders.each do |folder|
      parent_folders.add File.expand_path folder + "/.."
    end

    parent_folders.to_a
  end

  def static_project_path_re
    Regexp.new(@static_project_names.to_a.map { |project| "^#{project}/static.*/.*"}.join('|'))
  end

  def add_project_alias(path_name, real_project_name)
    @project_aliases[path_name] = real_project_name
  end

  def aliased_project_name(name)
    @project_aliases[name] || name
  end

  def gather_dependent_build_names
    @static_project_paths.each do |path|
      project_name = path.split('/')[-1]
      project_deps = StaticDependencies::build_from_filesystem path, 'static', only_use_production_builds

      # If the project repo folder doesn't line up with the real project name (from static_conf.json), store the alias
      add_project_alias(project_name, project_deps.project_name) unless project_name == project_deps.project_name

      @dependencies_for = project_deps.recursively_fetch_all_latest_static_build_names "file://#{local_static_archive.archive_dir}", { :local => true, :served_projects_path_map => @static_projects_path_map }, @dependencies_for
    end
  end

end