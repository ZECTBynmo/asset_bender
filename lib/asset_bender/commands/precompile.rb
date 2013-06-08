# require 'asset_bender/patches/custom_manifiest_compiler'
require 'sprockets-derailleur'

module AssetBender
  module Commands
    class Precompile < BaseCommand

      def parse_options
        @project_input = @args[0]
        @project_path = File.expand_path @project_input
        @project_name = File.basename @project_path

        @output = @options[:output]

        # If the num processes isn't specified determine the number of physical CPUs
        @processes = @options[:processes].to_i unless @options[:processes].nil?
        @processes ||= SprocketsDerailleur::number_of_processors rescue 1
      end

      def run
        setup_command_env({ :extra_projects => [@project_path] })
        setup_sprockets

        # Clear out the output directory
        FileUtils.rm_rf File.join(@output, @project_name)

        logger.info "Starting assets pre-compile with #{@processes} processes"
        manifest = Sprockets::Manifest.new @sprockets.index, @output, @processes

        profile = false

        if profile
            require 'ruby-prof'

            # Profile the code
            RubyProf.start
        end

        # manifest.compile_prefixed_files_without_digest "#{@project_name}/"

        # Only include paths that start with the passed in prefix
        prefix = "#{@project_name}/"
        paths = @sprockets.each_logical_path.to_a

        puts "paths before: \n#{paths.inspect}"

        paths = paths.select { |path| true if path.start_with? prefix }

        # Sort longest paths first in a simplistic attempt try to compile the
        # bigger "bundle" files—that depend on lots of other files—last
        paths = paths.sort do |a,b|
            b.length <=> a.length
        end

        print "\n", "paths:\n"
        puts paths.join("\n")

        manifest.compile paths

        if profile
            result = RubyProf.stop

            # Print a flat profile to text
            printer = RubyProf::FlatPrinter.new(result)
            # printer = RubyProf::GraphPrinter.new(result)
            printer.print(STDOUT)
        end

      end

    end
  end
end
