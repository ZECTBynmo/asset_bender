module Sprockets
  class Manifest

    def compile_prefixed_files_without_digest(prefix)
      unless environment
        raise Error, "manifest requires environment for compilation"
      end

      paths = environment.each_logical_path.to_a
      paths = paths.select { |path| path if path.start_with? prefix }

      print "\n", "paths:  #{paths.inspect}", "\n\n"

      paths.each do |path|
        if asset = find_asset(path)
          
          files[asset.logical_path] = {
            'logical_path' => asset.logical_path,
            'mtime'        => asset.mtime.iso8601,
            'size'         => asset.bytesize,
          }

          target = File.join(dir, asset.logical_path)

          if File.exist?(target)
            logger.debug "Skipping #{target}, already exists"
          else
            logger.info "Writing #{target}"
            asset.write_to target
          end

          save
          asset
        end
      end
    end

  end
end
