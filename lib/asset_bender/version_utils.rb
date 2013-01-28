
module AssetBender
  module VersionUtils
    def self.project_replacement_regex(project_name)
        project_name_escaped = Regexp.escape(project_name)
        Regexp.new "#{project_name_escaped}\/(static|version|[\\w-]+)/", Regexp::MULTILINE
    end

    def self.project_with_version(project_name, semver, version_format = nil)
        version_format ||= AB::Version::URL_OUTPUT_FORMAT
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
