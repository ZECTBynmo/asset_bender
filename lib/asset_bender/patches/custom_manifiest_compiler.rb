module Sprockets
  class Manifest

    def compile_prefixed_files_without_digest(prefix)
      unless environment
        raise Error, "manifest requires environment for compilation"
      end

      paths = environment.each_logical_path.to_a

      # Only include paths that start with the passed in prefix
      paths = paths.select { |path| true if path.start_with? prefix }

      # Skip all files without extensions, see
      # https://github.com/sstephenson/sprockets/issues/347 for more info
      paths = paths.select do |path|

        if File.extname(path) == ""
          logger.info "Skipping #{path} since it has no extension"
          false
        else
          true
        end
      end

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
