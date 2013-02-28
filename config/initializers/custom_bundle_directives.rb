# So this is quite a lot of crazy monkeypatching, just to create the
# //= wrap_with_anonymous_function directive. Probably should have punted
# in the first place :/
#
# (And it depends on using UnglifierJS since I had to patch the compressor too)

# Now this is also being used to munge build names into served assets on the fly though

WrapMarker = "/** _anon_wrapper_ **/"
AnonFunc = "(function() {"

AnonWrapperStartPieces = [WrapMarker, AnonFunc]
AnonWrapperStart = AnonWrapperStartPieces.join(';')
AnonWrapperEnd = "})(); #{WrapMarker}"

AnonWrapperStartRegex = Regexp.new("#{Regexp.escape(AnonWrapperStart)}\\s*$")

AnonWrapperCleanupRegex = Regexp.new("(#{Regexp.escape(AnonWrapperStartPieces[0])}[\\s\\n]*;?[\\s\\n]*\\(function\\(\\)\\s*\\{\\s*\\n*;?\\n*)", Regexp::MULTILINE)
AnonWrapperEndCleanupRegex = Regexp.new("(\\}\\)\\(\\);?\\s*#{Regexp.escape(WrapMarker)};?\\n*)", Regexp::MULTILINE)

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

class HubspotBundleJSDirectiveProcessor < HubspotAssetDirectiveProcessor
    def render(scope=Object.new, locals={}, &block)
        result = super

        if result and AnonWrapperCleanupRegex =~ result
            result.gsub! AnonWrapperCleanupRegex, ""
            result = AnonWrapperStart + "\n" + result
        end

        result
    end
end

class HubspotJSDirectiveProcessor < HubspotAssetDirectiveProcessor
    @is_wrapped = false

    def process_wrap_with_anonymous_function_directive
        @is_wrapped = true
    end

    def render(scope=Object.new, locals={}, &block)
        result = super

        if @is_wrapped
            result = AnonWrapperStart + "\n" + result + "\n" + AnonWrapperEnd
        end

        result
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



class Uglifier
    alias_method :_orig_compile, :compile
    def wrapped_compile(source)
        wrapped = false

        if source and AnonWrapperCleanupRegex =~ source and AnonWrapperEndCleanupRegex =~ source
            wrapped = true
            source.gsub! AnonWrapperCleanupRegex, ""
            source.gsub! AnonWrapperEndCleanupRegex, ""
        end

        result = _orig_compile(source)


        if wrapped
            join_char = Rails.env.compressed? ? "" : "\n"
            result = [AnonWrapperStart, result, AnonWrapperEnd].join(join_char)
        end

        result
    end
    alias_method :compile, :wrapped_compile
    alias_method :compress, :wrapped_compile
end


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

# Setting this variable will cause the compilier to ignore all "//= require ..." lines,
# essentially preventing any bundles from being compiled
if ENV['INGNORE_BUNDLE_DIRECTIVES']
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


# Fix the location of the generated sprite and ensure that the generated sprite
# filename is consistent across deps, versions, etc
# Overwriting method from /compass-0.12.2/lib/compass/sass_extensions/sprites/sprite_methods.rb

module Compass
  module SassExtensions
    module Sprites
      module SpriteMethods
        
        def filename
          project = extract_project_from_path name_and_hash
          path = Rails.application.config.hubspot.served_projects_path_map[project] || Rails.application.config.hubspot.served_dependency_path_map[project]

          File.join File.split(path)[0], name_and_hash
        end

        def strip_version_from_path(path)
            path.gsub(/\/static-\d+\.\d+\//, '/static/')
        end

        def uniqueness_hash
          @uniqueness_hash ||= begin
            sum = Digest::MD5.new

            sum << SPRITE_VERSION
            sum << layout

            # Strip the version from this top-level path as well
            sum << strip_version_from_path(path)

            images.each do |image|

              # Remove the version from the relative_file path so that the hash generated
              # is consistent across different builds
              stripped_relative_file = strip_version_from_path(image.relative_file.to_s)
              sum << stripped_relative_file

              # Skips :relative_file since that is handled above
              [:height, :width, :repeat, :spacing, :position, :digest].each do |attr|
                sum << image.send(attr).to_s
              end
            end

            sum.hexdigest[0...10]
          end
          @uniqueness_hash
        end

      end
    end
  end
end
