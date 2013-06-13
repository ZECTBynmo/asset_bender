require 'forwardable'

module AssetBender

  class Config

    FILENAME = "config.yaml"
    PATH = "~/.bender/"

    @skip_global_config = false
    class << self
      attr_accessor :skip_global_config
    end

    extend ConfLoaderUtils
    include LoggerUtils
    extend LoggerUtils

    extend SingleForwardable
    extend CustomSingleton

    DEFAULT_CONFIG = {
      :build_hash_filename => "premunged-static-contents-hash.md5",
      :denormalized_dependencies_filename => "denormalized-deps.json",
      :info_filename => "info.txt",

      :static_domain => "",
      :prefixed_static_domain => "",
    }

    # Load the global config singleton that will be avialble as:
    #
    #    AssetBender::Config.get_whatever_setting
    #
    def self.instance
      if @skip_global_config
        @@global_config ||= Config.load_empty
      else
        @@global_config ||= Config.load
      end
    end

    # Delegate to the singleton methods
    def_delegators :instance, :update!, :[], :[]=, :method_missing, :to_hash

    def self.filename
      File.expand_path File.join PATH, FILENAME
    end

    # Creates a new config object by loading the data at filename (json
    # or yaml). If the "extends" key exists in that data, it preloads
    # config with the file (or files) specified.
    def self.load(filename_to_load = nil)

      # Only autocreate the config file if we are using the default one
      # (e.g. they didn't manually specify where the config file lives)
      create_if_doesnt_exist = filename_to_load.nil?

      filename_to_load ||= filename

      logger.info "Loading config: #{filename_to_load}"

      begin
        config_data = load_json_or_yaml_file filename_to_load
      rescue Errno::ENOENT
        logger.warn "Config file doesn't exist at: #{filename_to_load}. Creating one."
        create_brand_new_config_file if create_if_doesnt_exist
      end

      config = FlexibleConfig.new DEFAULT_CONFIG

      # Inherited config
      extended_config_files(config_data).each do |parent_config_file|
        config.update! load_parent_config parent_config_file
      end

      config.update! config_data
      config
    end

    def self.load_empty
      FlexibleConfig.new DEFAULT_CONFIG
    end

    # Retrieves the "extends" key, deletes it from the passed hash
    # and returns an array—forcing a single string to single element
    # array and nil to an empty array.
    def self.extended_config_files(data)
      extends = data.delete :extends

      case extends
        when String then [extends]
        when Enumerable then extends
        else []
      end
    end

    # Get's the data for a parent config. It first looks to see if the passed name
    # is a registered base config. If it isn't found there, then it tries to load
    # it off the filesystem
    def self.load_parent_config(name_or_file)
      logger.info "Loading base config: #{name_or_file}"

      if BASE_CONFIGS.has_key? name_or_file
        parent_config = BASE_CONFIGS[name_or_file]

        if parent_config.respond_to? :call
          parent_config.call
        else
          parent_config
        end
      else
        logger.warn "No such #{name_or_file} base config, looking for it on the filesystem"
        load_json_or_yaml_file File.expand_path name_or_file
      end
    end

    # Register a base config that other config files can extend.
    #
    #    Config.register_extendable_base_config('mycompany', hash_of_defaults)
    #
    #    OR
    #
    #    Config.register_extendable_base_config 'mycompany', do
    #      ... # returning a hash
    #    end
    #
    def self.register_extendable_base_config(name, data = nil, &block)
      logger.info "Registering an extendedable base config: #{name}"
      BASE_CONFIGS[name] = data || block
    end

    # List the names of all the registered base configs
    def self.registered_base_configs
      BASE_CONFIGS.keys
    end

    def self.set_brand_new_config_template(contents)
      CONFIG_TEMPLATES.push contents
    end

    def self.create_brand_new_config_file
      # Grab the last set template off the stack
      template = CONFIG_TEMPLATES[-1] || BASE_TEMPLATE

      logger.warn "Writing the brand new template isn't implemented yet"
      print "\n", "template:  #{template}", "\n\n"
    end

    # Load all files in the config folder (since base configs are defined there)
    def self.load_all_base_config_files
      Dir[File.expand_path(File.join(__FILE__,'../../../config/*.rb'))].each do |file|
        logger.info "Loading initial base config: #{file}"
        require file
      end
    end

    private

    BASE_CONFIGS = {}

    CONFIG_TEMPLATES = []   # Stack of base templates provided by extensions
    BASE_TEMPLATE = """# Empty bender config, required fields must be filled out!
# Required
# domain: domain.for.your.s3.bucket.com
# cdn_domain: domain.for.your.cdn.com

# Local projects you want the bender server to serve (can be
# overridden with command line arguments). Basically this should
# include all the projects you need to edit.
local_projects:
#  - ~/dev/src/bla
#  - ~/dev/src/somewhere/else/foobar

# Optional
# port: 3333

# Note, if you change this file you need to restart the bender server
"""

  end
end

