module AssetBender
    class VersionMunger
        extend AssetBender::VersionUtils

        def self.peek_for_deps_that_potentially_need_munging(deps, data)
            deps.select do |dep|
                # Any potential paths for the passed in dependencies?
                data.include? "#{dep.name}/"
            end
        end

        def self.munge_build_names_for_dependencies(project, data)
            return unless project

            deps = project.resolved_dependencies.select do |project_or_dep|
                project_or_dep.is_dependency
            end

            # Quick check to see if any munging is necessary (for performance)
            deps = peek_for_deps_that_potentially_need_munging deps, data
            return if deps.empty?

            deps.each do |dep|
                path_prefix_for_dep = dep.name_plus_version_prefix
                data.gsub!(/\b#{Regexp.escape(dep.prefix_to_replace)}/, path_prefix_for_dep)
            end
        end
    end
end