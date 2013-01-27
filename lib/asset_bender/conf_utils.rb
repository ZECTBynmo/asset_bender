require 'yaml'

module AssetBender
  module ConfUtils

    # Pattern to have class methods show up in an included class:
    # http://stackoverflow.com/questions/10039039/why-self-method-of-module-cannot-become-a-singleton-method-of-class
    module ClassMethods
      def load_json_or_yaml_file(path)
        YAML.load_file File.expand_path path
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

  end
end
