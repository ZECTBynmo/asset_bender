require 'yaml'

module AssetBender

  # Methods for any class that needs to load yaml or json from
  # the filesystem
  module ConfLoaderUtils
    def load_json_or_yaml_file(path)
      # JSON is a subset of YAML, so we can parse both with a single call
      hash = YAML.load_file File.expand_path path

      # Normalize string keys to symbols
      hash = transform_keys_to_symbols hash
    end

    private

    #take keys of hash and transform those to a symbols
    def transform_keys_to_symbols(value)
      return value unless value.is_a?(Hash)
      value.inject({}){|memo,(k,v)| memo[k.to_sym] = transform_keys_to_symbols(v); memo}
    end
  end
end
