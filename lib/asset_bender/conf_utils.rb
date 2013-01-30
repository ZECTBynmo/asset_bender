require 'yaml'

module AssetBender

  # Methods for any class that needs to load yaml or json from
  # the filesystem
  module ConfLoaderUtils

    # Pattern to have class methods show up in an included class:
    # http://stackoverflow.com/questions/10039039/why-self-method-of-module-cannot-become-a-singleton-method-of-class
    module ClassMethods
      def load_json_or_yaml_file(path)
        # JSON is a subset of YAML, so we can parse both with a single call
        YAML.load_file File.expand_path path
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end


  # Based off of http://mjijackson.com/2010/02/flexible-ruby-config-objects and tweaked
  # to better deal with nested hashes (merging, export, etc)
  class FlexibleConfig

    def initialize(data={})
      @data = {}
      update!(data)
    end

    def update!(data)
      data.each do |key, value|
        if self[key] && self[key].is_a?(FlexibleConfig) && value.is_a?(Hash)
          self[key].update! value
        else
          self[key] = value
        end
      end
    end

    def [](key)
      @data[key.to_sym]
    end

    def []=(key, value)
      if value.class == Hash
        @data[key.to_sym] = FlexibleConfig.new(value)
      else
        @data[key.to_sym] = value
      end
    end

    def method_missing(sym, *args)
      if sym.to_s =~ /(.+)=$/
        self[$1] = args.first
      else
        self[sym]
      end
    end

    # Export as a hash (recusively converting FlexibleConfig objects to hashes)
    def to_hash
      @data.each_with_object({}) do |(key, value), output|
        if value.is_a? FlexibleConfig
          output[key] = value.to_hash
        else
          output[key] = value
        end
      end
    end

  end
end
