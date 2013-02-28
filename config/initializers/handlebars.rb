require 'execjs'
require 'pathname'
require 'sprockets'
require 'tilt'

# From https://github.com/leshill/handlebars_assets/blob/master/lib/handlebars_assets/config.rb

module HandlebarsAssets
  # Change config options in an initializer:
  #
  # HandlebarsAssets::Config.path_prefix = 'app/templates'
  module Config
    extend self

    attr_writer :compiler, :compiler_path, :known_helpers, :known_helpers_only, :options, :path_prefix, :template_namespace

    def compiler
      @compiler || 'handlebars.js'
    end

    def compiler_path
      @compiler_path || File.expand_path("../../../vendor/assets/javascripts", __FILE__)
    end

    def known_helpers
      @known_helpers || []
    end

    def known_helpers_only
      @known_helpers_only || false
    end

    def options
      @options ||= generate_options
    end

    def path_prefix
      @path_prefix || 'templates'
    end

    def template_namespace
      @template_namespace || 'Handlebars.templates'
    end

    private

    def generate_known_helpers_hash
      known_helpers.inject({}) do |hash, helper|
        hash[helper] = true
      end
    end

    def generate_options
      options = @options || {}
      options[:knownHelpersOnly] = true if known_helpers_only
      options[:knownHelpers] = generate_known_helpers_hash if known_helpers.any?
      options
    end

  end
end

# From https://github.com/leshill/handlebars_assets/blob/master/lib/handlebars_assets/handlebars.rb

class Handlebars
  class << self
    def precompile(*args)
      context.call('Handlebars.precompile', *args)
    end

    private

    def context
      @context ||= ExecJS.compile(source)
    end

    def source
      @source ||= path.read
    end

    def path
      @path ||= assets_path.join(HandlebarsAssets::Config.compiler)
    end

    def assets_path
      @assets_path ||= Pathname(HandlebarsAssets::Config.compiler_path)
    end
  end
end

# From https://github.com/leshill/handlebars_assets/blob/master/lib/handlebars_assets/tilt_handlebars.rb

class TiltHandlebars < Tilt::Template
  def self.default_mime_type
    'application/javascript'
  end

  def evaluate(scope, locals, &block)
    template_path = TemplatePath.new(scope)
    template_name = template_path.filename_minus_extension

    compiled_hbs = Handlebars.precompile(data, HandlebarsAssets::Config.options)

    template_namespace = HandlebarsAssets::Config.template_namespace

    if template_path.is_partial?
      <<-PARTIAL
        (function() {
          Handlebars.registerPartial("#{template_name}", Handlebars.template(#{compiled_hbs}));
        }).call(this);
      PARTIAL
    else
      <<-TEMPLATE
        (function() {
          this.#{template_namespace} || (this.#{template_namespace} = {});
          this.#{template_namespace}["#{template_name}"] = Handlebars.template(#{compiled_hbs});
          return this.#{template_namespace}["#{template_name}"];
        }).call(this);
      TEMPLATE
    end
  end

  protected

  def prepare; end

  class TemplatePath
    def initialize(scope)
      # Need to use the full pathname instead of the logical_path because the logical_path
      # strips anything after a period (and we have folders like "static-2.43" that 
      # have periods in them)
      self.template_path = scope.pathname.to_s
    end

    def is_partial?
      filename_minus_extension.start_with?('_')
    end

    def name
      is_partial? ? partial_name : template_path
    end

    def filename_minus_extension
      File.basename(template_path, ".handlebars")
    end

    private

    attr_accessor :template_path

    def forced_underscore_name
      '_' + relative_path
    end

    def partial_name
      forced_underscore_name.gsub(/\//, '_').gsub(/__/, '_').dump
    end
  end
end

# From https://github.com/leshill/handlebars_assets/blob/master/lib/handlebars_assets.rb

Rails.application.assets.register_engine('.handlebars', TiltHandlebars)

