module AssetBender
    class VersionMunger

        def self.peek_for_potential_strings_needing_munging(deps, data)
            deps.each do |dep|
                # Any paths for the passed in dependencies?
                return true if data.include? "#{dep.name}/"
            end
        end

        def self.munge_build_names_for_dependencies(project, data)
            return unless project

            deps = project.resolved_dependencies.select do |project_or_dep|
                project_or_dep.is_dependency
            end

            # Quick check to see if any munging is necessary (for performance)
            return unless peek_for_potential_strings_needing_munging deps, data

            deps.each do |dep|
                if dep.is_legacy?
                    data.gsub! "#{dep.name}/static/", "#{dep.name}/#{dep.version.to_legacy_hubspot_version}/"
                else
                    data.gsub! "#{dep.name}/", "#{dep.name}-#{dep.version.url_format}/"
                end
            end
        end
    end
end