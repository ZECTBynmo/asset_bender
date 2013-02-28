require 'execjs'
require 'pathname'
require 'sprockets'
require 'tilt'

# Ported from handlebars.rb.

module JadeAssets
  # Change config options in an initializer:
  #
  # JadeAssets::Config.path_prefix = 'app/templates'
  module Config
    extend self

    attr_writer :compiler, :compiler_path, :options, :path_prefix, :template_namespace

    def compiler
      @compiler || 'jade.js'
    end

    def compiler_path
      @compiler_path || File.expand_path("../../../vendor/assets/javascripts", __FILE__)
    end

    def options
      @options ||= generate_options
    end

    def path_prefix
      @path_prefix || 'templates'
    end

    def template_namespace
      @template_namespace || 'jade.templates'
    end

    private

    def generate_options
      options = @options || {}
      options[:client] = true
      options
    end

  end
end

class Jade
  class << self
    def compile(str, options)
      context.eval("jade.compile(#{str.to_json}, #{options.to_json}).toString()")
    end

    private

    def context
      @context ||= ExecJS.compile(source)
    end

    def source
      @source ||= path.read
    end

    def path
      @path ||= assets_path.join(JadeAssets::Config.compiler)
    end

    def assets_path
      @assets_path ||= Pathname(JadeAssets::Config.compiler_path)
    end
  end
end

class TiltJade < Tilt::Template
  def self.default_mime_type
    'application/javascript'
  end

  def evaluate(scope, locals, &block)
    template_path = TemplatePath.new(scope)
    template_name = template_path.filename_minus_extension

    compiled_template = Jade.compile(data, JadeAssets::Config.options)

    template_namespace = JadeAssets::Config.template_namespace

    # TODO: Add support for partials
      <<-TEMPLATE
        (function() {
          this.#{template_namespace} || (this.#{template_namespace} = {});
          this.#{template_namespace}["#{template_name}"] = #{compiled_template};
          return this.#{template_namespace}["#{template_name}"];
        }).call(this);
      TEMPLATE
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
      File.basename(template_path, ".jade")
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


Rails.application.assets.register_engine('.jade', TiltJade)

