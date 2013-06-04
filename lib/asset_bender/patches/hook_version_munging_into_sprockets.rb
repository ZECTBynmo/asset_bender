
# Monkey patch the directive processors to ensure that the build names are interpreted
# before any preprocessing happens (so that files are imported correctly)

module AssetBender
    class DirectiveProcessor < Sprockets::DirectiveProcessor

        def prepare
            project = AssetBender::ProjectsManager.get_project_from_path file
            AssetBender::VersionMunger.munge_build_names_for_dependencies project, data

            super
        end
    end
end


# Monkey patch PorcessedAsset to ensure that the build names are interpreted
# after preprocessing happens

module Sprockets
    class ProcessedAsset < Asset
        alias_method :_orig_initialize, :initialize
        def wrapped_initialize(environment, logical_path, pathname)
            _orig_initialize(environment, logical_path, pathname)

            project = AssetBender::ProjectsManager.get_project_from_path logical_path
            AssetBender::VersionMunger.munge_build_names_for_dependencies project, @source
        end
        alias_method :initialize, :wrapped_initialize
    end
end

