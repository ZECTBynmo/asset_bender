require 'semver-tribe'

module AssetBender
  module VersionUtils
    # Default format '1.2.3'
    FORMAT = '%M.%m.%p-%s'

    # URL version format 'v1.2.3'
    URL_OUTPUT_FORMAT = 'v%M.%m.%p%s'

    # Other acceptable/legacy formats: 'v1.2.3', 'static-1.2'
    ALTERNATE_FORMATS = ['v%M.%m.%p-%s', 'static-%m.%p']

    # All acceptable formats together
    ALL_FORMATS = [FORMAT] + ALTERNATE_FORMATS

    def self.parse_version(version)
        ALL_FORMATS.each do |format|
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

    def self.project_with_version(project_name, semver, version_format = nil)
        version_format ||= URL_OUTPUT_FORMAT
        "#{project_name}/#{semver.format version_format}/"
    end

    def self.replace_project_versions_in(string_to_replace, project_name, semver)
        re = project_replacement_regex project_name
        value = project_with_version project_name, semver

        string_to_replace.gsub! re, value
    end

    def self.replace_all_projects_versions_in(string_to_replace, versions_by_project)
        versions_by_project.each do |project_name, semver|
            replace_project_versions_in string_to_replace, project_name, semver
        end
    end

  end
end
