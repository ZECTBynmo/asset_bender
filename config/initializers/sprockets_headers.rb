# Copied and modified directly from /sprockets-2.1.2/lib/sprockets/server.rb

module Sprockets
  module Server

      alias_method :_orig_headers, :headers
      def wrapped_headers(env, asset, length)
        output = _orig_headers(env, asset, length)

        # Ensure that font files have CORs headers
        if ['application/octet-stream', "image/svg+xml", "application/x-font-ttf", "application/x-font-truetype", "application/x-font-opentype", "application/x-font-woff" , "application/vnd.ms-fontobject"].include? asset.content_type
          output['Access-Control-Allow-Origin'] = '*'
        end

        output
      end
      alias_method :headers, :wrapped_headers
  end
end
