
def munge_build_names_for_dependencies(project_name, data)
    deps = Rails.application.config.hubspot.dependencies_for[project_name] || {}
    served_projects = Rails.application.config.hubspot.static_project_names

    # Quick check to see if any munging is necessary (for performance)
    return if not data.include? '/static/' or not project_name

    deps.each do |dep, build_name|
        data.gsub! "#{dep}/static/", "#{dep}/#{build_name}/" unless served_projects.include? dep
    end
end

def extract_project_from_path(path)
    return unless path

    tokens = path.split('/').compact
    index = tokens.rindex { |token| token =~ /^static(-\d\.\d+)?$/ }

    Rails.application.config.hubspot.aliased_project_name(tokens[index - 1]) if index && index > 0
end

# Monkey patch the directive processors to ensure that the build names are interpreted
# before any preprocessing happens (so that files are imported correctly)

class HubspotAssetDirectiveProcessor < Sprockets::DirectiveProcessor
    def prepare
        project_name = extract_project_from_path file
        munge_build_names_for_dependencies project_name, data

        super
    end
end

class HubspotBundleCSSDirectiveProcessor < HubspotAssetDirectiveProcessor
end

class HubspotCSSDirectiveProcessor < HubspotAssetDirectiveProcessor
end


# Replace the current js processor with our own:
Rails.application.assets.unregister_processor('application/javascript', Sprockets::DirectiveProcessor)
Rails.application.assets.register_processor('application/javascript', HubspotJSDirectiveProcessor)

# Replace the current css processor with our own:
Rails.application.assets.unregister_processor('text/css', Sprockets::DirectiveProcessor)
Rails.application.assets.register_processor('text/css', HubspotCSSDirectiveProcessor)

Rails.application.assets.register_bundle_processor('application/javascript', HubspotBundleJSDirectiveProcessor)
Rails.application.assets.register_bundle_processor('text/css', HubspotBundleCSSDirectiveProcessor)



# Monkey patch PorcessedAsset to ensure that the build names are interpreted
# after preprocessing happens

module Sprockets
    class ProcessedAsset < Asset
        alias_method :_orig_initialize, :initialize
        def wrapped_initialize(environment, logical_path, pathname)
            _orig_initialize(environment, logical_path, pathname)

            project_name = extract_project_from_path logical_path
            munge_build_names_for_dependencies project_name, @source
        end
        alias_method :initialize, :wrapped_initialize
    end
end


# Setting this config will cause the compilier to ignore all "//= require ..." lines,
# essentially preventing any bundles from being compiled
if AssetBender::Config.ingnore_bundle_directives
    HubspotAssetDirectiveProcessor.class_eval do
        def process_require_directive(path)
        end

        def process_include_directive(path)
        end

        def process_require_directory_directive(path = ".")
        end

        def process_require_tree_directive(path = ".")
        end
    end
end
