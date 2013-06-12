require 'rack/livereload'

# require 'rack/livereload/body_processor'

# Since sprockets caches asset HTML output, rack reload re-inserts the HTML snippet in
# every single time. This patch checks to see if the code was already inserted before
# modifying the output.

module Rack
  class LiveReload
    class BodyProcessor

      def process!(env)
        @env = env
        @livereload_added = false
        @body.close if @body.respond_to?(:close)

        @new_body = [] ; @body.each do |line|
          line_string = line.to_s

          # Check to see if the livereload snippet was already added
          if not @livereload_added and line_string.include? 'RACK_LIVERELOAD_PORT'
            @livereload_added = true
          end

          @new_body << line_string
        end

        @content_length = 0

        @new_body.each do |line|
          if !@livereload_added && line['<head']
            line.gsub!(HEAD_TAG_REGEX) { |match| %{#{match}#{template.result(binding)}} }

            @livereload_added = true
          end

          @content_length += line.bytesize
          @processed = true
        end
      end

    end
  end
end

