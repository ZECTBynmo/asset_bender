require 'etc'

# Fix issue with Psync vs syck in yaml files from the i18n gem
YAML::ENGINE.yamler= 'syck'

require 'action_view'
require 'git'

CurrentUser = Etc.getlogin

module AssetBender
  class LocalProject < Project
    attr_reader :path, :spec_directory

    POSSIBLE_SPEC_DIRS = [
      'static/test/spec',
      'spec'
    ]

    include ActionView::Helpers::DateHelper

    def initialize(config, path_to_project)
      super config
      @path = path_to_project

      check_for_alias
      check_for_spec_directory
    end

    def version_to_build
      if @version.is_wildcard
        @version
      else
        raise "This project has a fixed version specified, so version_to_build doesn't make sense"
      end
    end

    def check_for_alias
      parent_directory = File.basename @path
      @alias = parent_directory if parent_directory != @name
    end

    def has_specs?
      !@spec_directory.nil?
    end

    def check_for_spec_directory
      POSSIBLE_SPEC_DIRS.each do |dir|
        potential_spec_dir = File.join @path, dir
        return @spec_dir = potential_spec_dir if File.directory? potential_spec_dir
      end
    end

    def last_modified
      stat = File.stat @path
      stat.mtime
    end

    def last_modified_ago
      result = distance_of_time_in_words_to_now(last_modified)
      result.sub!(/^(\d+)/, "<span class=time-delta-value>\\1</span>")
      result + " ago"
    end

    def git
      return if @_git == false

      begin
        @_git ||= Git.open @path
      rescue
        logger.warn '#{@path} is not a git repo'
        @_git = false
      end
    end

    def outstanding_commits(remote_branch = nil)
      git.log.between(remote_branch, 'HEAD').count
    end

    def incoming_commits(remote_branch = nil)
      git.log.between('HEAD', remote_branch).count
    end

    def current_branch
      git.lib.branch_current
    end

    def remote_branch
      # Fragile for now
      "#{git.remote}/#{current_branch}"
    end

    def repo_url branch
      return nil if git.nil?

      url = git.remote.url
      branch ||= ""

      print "\n", "url:  #{url.inspect}", "\n\n"
      print "\n", "branch:  #{branch.inspect}", "\n\n"

      # Clean up the origin url and convert to github url
      url = url.sub(/^[^@]@/, '').sub(/\.git$/, '')
      url = url.sub(/\.com:/, '.com/')
      url = "http://#{url}"

      # Get rid of the the remote name from the branch string
      branch = branch.to_s.split('/')[1..-1].join('/') if branch.to_s['/']

      if branch
        "#{url}/tree/#{branch}"
      else
        url
      end
    end

    def repo_info
      return unless git

      curr_remote_branch = remote_branch
      outstanding = outstanding_commits remote_branch
      incoming = incoming_commits remote_branch

      outstanding_str = incoming_str = nil
      outstanding_str = "<span class=outstanding>+#{outstanding}</span>"if outstanding > 0
      incoming_str = "<span class=incoming>-#{incoming}</span>" if incoming > 0

      if outstanding_str || incoming_str
        result = "#{[outstanding_str, incoming_str].compact.join ' and '} commits from "
      else
        result = "up to date with "
      end

      result += "<a class=remote-branch href=\"#{repo_url remote_branch}\">#{remote_branch}</a>"
    end

    def pretty_path
      output = @path
      output.sub /\/(Users|home)\/#{CurrentUser}\//i, '~/'
    end

    def parent_path
      File.split(@path)[0]
    end

    def self.load_from_file(path)
      project_config = load_config_from_file path
      self.new project_config, path
    end
  end
end