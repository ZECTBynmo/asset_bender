require 'execjs'
require 'pathname'
require 'sprockets'
require 'tilt'

# Ported from handlebars.rb.

module DustJSAssets
  # Change config options in an initializer:
  #
  # DustJSAssets::Config.path_prefix = 'app/templates'
  module Config
    extend self

    attr_writer :compiler, :compiler_path, :options, :path_prefix

    def compiler
      @compiler || 'dust.js'
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

    private

    def generate_options
      options = @options || {}
      options
    end

  end
end

class DustJS
  class << self
    def compile(str, template_name)
      context.eval("dust.compile(#{str.to_json}, #{template_name.to_json})")
    end

    private

    def context
      @context ||= ExecJS.compile(source)
    end

    def source
      @source ||= path.read
    end

    def path
      @path ||= assets_path.join(DustJSAssets::Config.compiler)
    end

    def assets_path
      @assets_path ||= Pathname(DustJSAssets::Config.compiler_path)
    end
  end
end

class TiltDustJS < Tilt::Template
  def self.default_mime_type
    'application/javascript'
  end

  def evaluate(scope, locals, &block)
    template_path = TemplatePath.new(scope)
    template_name = template_path.sub_path

    DustJS.compile(data, template_name)
  end

  protected

  def prepare; end

  class TemplatePath
    def initialize(scope)
      # Need to use the full pathname instead of the logical_path because the logical_path
      # strips anything after a period (and we have folders like "static-2.43" that
      # have periods in them)
      self.full_template_path = scope.pathname.to_s

      # print "\n", "scope.pathname.to_s:  #{scope.pathname.to_s.inspect}", "\n\n"
      # "/Users/timmfin/dev/hubspot/github/style_guide_prototype/static/html/dust-test.dust"
    end

    def filename_minus_extension
      File.basename(full_template_path, ".dust")
    end

    def path_from_static
      full_template_path.split(/\/static(-\d+\.\d+)?\//)[-1]
    end

    def sub_path
      dirs = path_from_static.split('/')
      num_dirs = dirs.length - 1

      # If the template is located at  /static/bla.dust or /static/dir/bla.dust
      # register the template name as "bla"
      if num_dirs < 2
        filename_minus_extension

      # Otherwise if the template is located at /static/dir/second/bla.dust,
      # register the template as "second/bla"
      else
        dirs[1..-2].join('/') + "/#{filename_minus_extension}"
      end
    end

    private

    attr_accessor :full_template_path
  end
end


Rails.application.assets.register_engine('.dust', TiltDustJS)

