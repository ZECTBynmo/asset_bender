require 'semver-tribe'

module AssetBender

  class VersionError < Error; end

  # Any kind of version in Asset Bender. That includes:
  #
  #   - A special version string like "recommended" or "edge"
  #   - A fixed semantic version like "1.2.3"
  #   - A wildcard semantic version like "1.x.x"
  #
  class Version
    extend Forwardable

    # Default format '1.2.3'
    FORMAT = '%M.%m.%p%s'

    # URL version format 'v1.2.3'
    URL_OUTPUT_FORMAT = 'v%M.%m.%p%s'

    # Other acceptable/legacy formats: 'v1.2.3', 'static-1.2'
    ALTERNATE_FORMATS = ['v%M.%m.%p%s', 'static-%m.%p']

    # All acceptable formats together
    ALL_FORMATS = [FORMAT] + ALTERNATE_FORMATS

    def initialize(version_string)
      if SpecialVersion.is_valid_version version_string
        @proxy = @special = SpecialVersion.new version_string
      else
        @proxy = @semver = Version.parse_semver version_string 
        raise AssetBender::VersionError.new "Invalid version string: #{version_string}" if @semver.nil?
      end
    end

    def method_missing(method, *args, &block)    
      if @semver.nil?
        @special.send(method, *args, &block)
      elsif @semver.respond_to?(method)
        @semver.send(method, *args, &block)
      else
        raise NoMethodError  
      end    
    end
    
    def to_s
      if @semver.nil?
        @special.to_s
      else
        @semver.format FORMAT
      end
    end

    def url_format
       @proxy.format URL_OUTPUT_FORMAT
    end
    alias_method :path_format, :url_format

    def abbrev
      if @semver.nil?
        @special.abbrev 
      else
        to_s
      end
    end

    def is_special_build_string?
       @semver.nil?
    end

    def is_fixed?
      !is_special_build_string? && !@semver.is_wildcard?
    end

    # Delegate the standard methods (minus to_s)
    def_delegators :@proxy, :inspect, :=~, :!~, :==, :===

    # CLASS METHODS

    def self.parse_semver(version_string)
      ALL_FORMATS.each do |format|
        semver = SemVer.parse version_string, format
        return semver unless semver.nil?
      end

      nil
    end

    def self.is_valid_version(version_string)
      SpecialVersion::VALID_STRINGS.include?(version_string) || !Version.parse_semver(version_string).nil?
    end

  end


  # A class that mimics (some() methods from the SemVer class, but only represents one
  # of these version specifiers:
  #
  #   "recommended" => Use the latest version that the project recommends (e.g. the latest
  #                    non-prerelease version)
  #
  #   "edge"        => Use the latest version of the project (including pre-releases)
  #
  # Note: "current" is a backwards-compatiable alias to "recommended"
  class SpecialVersion

    VALID_STRINGS = [
      'recommended',
      'current',      # sames as 'recommended', but legacy
      'edge'
    ]

    ALIASES = {
      'current' => 'recommended'
    }

    ABBREVIATIONS = {
      'recommended' => 'rec.'
    }

    def initialize(version_string)
      version_string = version_string.to_s
      @version_string = ALIASES[version_string] || version_string
    end

    def is_wildcard?
      true
    end

    def abbrev
      ABBREVIATIONS[@version_string] || @version_string
    end

    def format fmt = nil
      @version_string.dup
    end

    def to_s
      @version_string.dup
    end

    def <=> other
      return 0 if @version_string = other.version_string
      raise AssetBender::VersionError.new "Can't compare a 'special' version string (#{version_string}) to #{other}"
    end

    def self.is_valid_version(version_string)
      VALID_STRINGS.include? version_string
    end

  end
end