module AssetBender

  class Config < FlexibleConfig

    FILENAME = ".bender.yaml"
    PATH = "~/"

    include ConfLoaderUtils
    include LoggerUtils
    extend LoggerUtils

    def self.base_filename
      File.expand_path File.join PATH, FILENAME
    end

    # Creates a new config object by loading the data at filename (json
    # or yaml). If the "extends" key exists in that data, it preloads
    # config with the file (or files) specified.
    def self.load(filename = nil)
      filename ||= base_filename

      config_data = load_json_or_yaml_file filename
      config = Config.new

      # Inherited config
      extended_config_files(config_data).each do |parent_config_file|
        config.update! load_parent_config parent_config_file
      end

      config.update! config_data
      config
    end

    # Retrieves the "extends" key, deletes it from the passed hash
    # and returns an array—forcing a single string to single element
    # array and nil to an empty array.
    def self.extended_config_files(data)
      extends = data.delete "extends"

      case extends
        when String then [extends]
        when Enumerable then extends
        else []
      end 
    end

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
        load_json_or_yaml_file File.extend_path parent_config_file
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

    def self.registered_base_configs
      BASE_CONFIGS.keys
    end

    private

    BASE_CONFIGS = {}

  end

end

# Load all files in the config folder (since base configs are defined there)
Dir[File.expand_path(File.join(__FILE__,'../../../config/*.rb'))].each do |file|
  AssetBender::logger.info "Loading base config: #{file}"
  require file
end