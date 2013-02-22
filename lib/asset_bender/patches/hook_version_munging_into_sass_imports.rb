# Monkey patch the sass compiler so that imported sass files are munged

module Sass
    module Tree
        class ImportNode < RootNode

            alias_method :_orig_import, :import
            def import
                if @imported_filename.include? '/static/'
                    project_name = extract_project_from_path filename
                    munge_build_names_for_dependencies project_name, @imported_filename
                end

                _orig_import()
            end
            alias_method :import, :import
        end
    end
end
