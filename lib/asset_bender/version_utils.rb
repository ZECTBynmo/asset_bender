require 'semver'

module AssetBender
  module VersionUtils
    # Default format 'v1.2.3'
    @@VERSION_FORMAT = 'v%M.%m.%p-%s'

    # Other acceptable/legacy formats: '1.2.3' and 'static-1.2.3'
    @@ALTERNATE_VERSION_FORMATS = ['%M.%m.%p-%s', 'static-%m.%p']

    # All acceptable formats together
    @@ALL_VERSION_FORMATS = [@@VERSION_FORMAT] + @@ALTERNATE_VERSION_FORMATS

    def self.parse_version(version)
        @@ALL_VERSION_FORMATS.each do |format|
            semver = SemVer.parse version, format
            return semver unless semver.nil?
        end
    end

    def self.is_valid_version(version)
        semver = parse_version version
        !semver.nil?
    end

    def self.project_replacement_regex(project_name)
        project_name_escaped = Regexp.escape(project_name)
        Regexp.new "#{project_name_escaped}\/(static|version|[\\w-]+)/", Regexp::MULTILINE
    end

    def self.project_with_version(project_name, version, version_prefix = 'v')
        "#{project_name}/#{version_prefix}#{version}"
    end

    def self.replace_project_versions_in(string_to_replace, project_name, version_number)
    end

    def self.replace_all_projects_versions_in(string_to_replace, versions_by_project)
    end

  end
end

# Add a parse method to SemVer (from my fork at https://github.com/timmfin/semver)
class SemVer
    def self.parse(version_string, format = nil, allow_missing = true)
        format ||= TAG_FORMAT
        regex_str = Regexp.escape format

        # Convert all the format characters to named capture groups
        regex_str.gsub! '%M', '(?<major>\d+)'
        regex_str.gsub! '%m', '(?<minor>\d+)'
        regex_str.gsub! '%p', '(?<patch>\d+)'
        regex_str.gsub! '%s', '(?<special>[A-Za-z][0-9A-Za-z\.]+)?'

        regex = Regexp.new(regex_str)
        match = regex.match version_string

        if match
            major = minor = patch = nil
            special = ''

            # Extract out the version parts
            major = match[:major].to_i if match.names.include? 'major'
            minor = match[:minor].to_i if match.names.include? 'minor'
            patch = match[:patch].to_i if match.names.include? 'patch'
            special = match[:special] || '' if match.names.include? 'special'

            # Failed parse if major, minor, or patch wasn't found
            # and allow_missing is false
            return nil if !allow_missing and [major, minor, patch].any? {|x| x.nil? }

            # Otherwise, allow them to default to zero
            major ||= 0
            minor ||= 0
            patch ||= 0

            SemVer.new major, minor, patch, special
        end
    end
end