module AssetBender
  module Commands
    class ClearCache < BaseCommand

      def run
        system "rm -rf #{File.join bender_root, '/tmp/cache'}"
      end

    end
  end
end
