# Monkeypatches the each_entry method to speed up precompilation.
#
# This method is only really used to list all of the files available to sprockets
# (eg something the precompiler uses to iterate over). Since hs-static goofs with
# sprocket's logical path and adds a lot of extra directories, these patches ensure
# that sprocket's skips over all the directories that are not actively being 
# served (via conf.yaml or "-p").

module Sprockets
    class Base
        def each_entry(root, depth = 0, &block)
            return to_enum(__method__, root) unless block_given?
            root = Pathname.new(root) unless root.is_a?(Pathname)

            paths = []

            # We only what to muck with directories that are specified by deps or projects from hs-static
            is_a_project_or_archive_root = (depth == 0) && Rails.application.config.hubspot.static_project_parents.include?(root.to_s)

            entries(root).sort.each do |filename|
                path = root.join(filename)
                paths << path


                if stat(path).directory?
                    # If this is a directory from hs-static, only descend into it if is one of the projects
                    # currently being served
                    if is_a_project_or_archive_root
                            can_recurse = Rails.application.config.hubspot.static_project_paths.include?(path.to_s)
                    else
                            can_recurse = true
                    end

                    if can_recurse
                        each_entry(path, depth + 1) do |subpath|
                            paths << subpath
                        end
                    end
                end
            end

            paths.sort_by(&:to_s).each(&block)

            nil
        end
    end
end