require 'asset_bender/patches/custom_manifiest_compiler'

module AssetBender
  module Commands
    class Precompile < BaseCommand

      def parse_options
        @project_input = @args[0]
        @project_path = File.expand_path @project_input
        @project_name = File.basename @project_path

        @output = @options[:output]
      end

      def run
        setup_env({ :extra_projects => [@project_path] })
        setup_sprockets

        manifest = Sprockets::Manifest.new(@sprockets.index, @output)
        manifest.compile_prefixed_files_without_digest "#{@project_name}/"
      end

    end
  end
end
