module AssetBender
  class UnknownDependencyError < AssetBender::Error; end

  class LocalArchive

    def initialize(path)
      raise AssetBender::Error.new "No archive path specified" unless path

      @path = File.expand_path path
      check_if_directory_exists

      @filesystemFetcher = AssetBender::Fetcher.new({ :domain => "file://#{path}" })
      @remoteFetcher = AssetBender::Fetcher.new
    end

    def check_if_directory_exists
      if not File.directory? @path
        puts "You, don't have a #{@path} directory, creating it\n" 

        Dir::mkdir @path
      end
    end

    def available_dependencies
      @dependency_names ||= Dir.glob("#{@path}/*/").map do |dir|
        dir unless Dir[dir].empty?
      end.compact
    end

    def is_valid_dependency?(dependency_name)
      available_dependencies.include? dependency_name
    end

    def available_versions_for_dependency(dependency_name)
      raise AssetBender::UnknownDependencyError.new "No such known dependency #{dependency_name}. Check to see if the configured dependencies are correct and you have run the update-deps command" unless is_valid_dependency? dependency_name

      Dir.glob(File.join(@path, dependency_name)).map do |dir|
        AssetBender::Version.new dir
      end
    end

    def dependency_exists?(dependency_name, version)
      dep_path = File.join @path, dependency_name.to_s, version.path_format
      Dir.exist?(dep_path)
    end

    def get_dependency(dependency_name, version)
      begin
        AssetBender::Dependency.load_from_file File.join @path, dependency_name.to_s, version.path_format
      rescue AssetBender::ProjectLoadError => e
        logger.error e
        nil
      end
    end

    def archive_name(dependency)
      resolved_version_string = dependency.resolved_version.url_format
      "#{dependency.name}-#{resolved_version_string}-src.tar.gz"
    end

    def archive_url(dep)
      archive_domain = AssetBender::Config.domain
      archive_prefix = AssetBender::Config.archive_url_prefix || ''

      "#{archive_domain}/#{archive_prefix}/#{archive_name(dep)}"
    end

  end
end