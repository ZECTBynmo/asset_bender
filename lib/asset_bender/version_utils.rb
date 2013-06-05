
module AssetBender
  module VersionUtils
    def self.find_index_of_string_in_path(url_or_path, potential_strings=nil)
        return unless url_or_path
        raise "No potential strings were passed." if potential_strings.nil?

        tokens = url_or_path.split('/').compact
        index = tokens.rindex { |token| potential_strings.include? token }
        [index, tokens]
    end

    def self.look_for_string_in_path(url_or_path, potential_strings=nil)
        index, tokens = find_index_of_string_in_path url_or_path, potential_strings        
        tokens[index] if index && index > 0
    end

    def self.look_for_string_preceding_version_in_path(url_or_path, potential_strings=nil)
        index, tokens = find_index_of_string_in_path url_or_path, potential_strings        
        
        if index && index > 0 && index + 1 < tokens.length
            string = tokens[index]
            version = AssetBender::Version.new tokens[index + 1]

            [string, version]
        end

    rescue AssetBender::VersionError => e
        logger.error(e)
        nil
    end

  end
end
