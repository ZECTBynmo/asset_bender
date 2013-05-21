require 'etc'

# Fix issue with Psync vs syck in yaml files from the i18n gem
YAML::ENGINE.yamler= 'syck'

require 'action_view'

CurrentUser = Etc.getlogin

module AssetBender
  class AbstractProject

    module RenderMethods
      include ActionView::Helpers::DateHelper
      
      def last_modified_ago
        result = distance_of_time_in_words_to_now(last_modified)
        result.sub!(/^(\d+)/, "<span class=time-delta-value>\\1</span>")
        result + " ago"
      end

      def pretty_path
        output = @path
        output.sub(/\/(Users|home)\/#{CurrentUser}\//i, '~/')
      end
    end

  end
end