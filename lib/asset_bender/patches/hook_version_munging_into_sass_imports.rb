# Monkey patch the sass compiler so that imported sass files are munged

module Sass
    module Tree
        class ImportNode < RootNode

            alias_method :_orig_import, :import
            def import
                project = AssetBender::ProjectsManager.get_project_from_path filename
                AssetBender::VersionMunger.munge_build_names_for_dependencies project, @imported_filename

                _orig_import()
            end
            alias_method :import, :import
        end
    end
end
