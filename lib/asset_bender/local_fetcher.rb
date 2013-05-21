module AssetBender
  class LocalFetcher < Fetcher
    def initialize(options = nil)
      options ||= {}
      options[:domain] ||= "file://#{File.expand_path(AssetBender::Config.archive_dir)}"

      super options
    end
  end
end
