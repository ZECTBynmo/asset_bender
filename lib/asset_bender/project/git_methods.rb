require 'git'

module AssetBender
  class AbstractProject

    module GitMethods
      def git
        return if @_git == false

        begin
          @_git ||= Git.open @path
        rescue
          logger.warn "#{@path} is not a git repo"
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
        outstanding = outstanding_commits curr_remote_branch
        incoming = incoming_commits curr_remote_branch

        outstanding_str = incoming_str = nil
        outstanding_str = "<span class=outstanding>+#{outstanding}</span>"if outstanding > 0
        incoming_str = "<span class=incoming>-#{incoming}</span>" if incoming > 0

        if outstanding_str || incoming_str
          result = "#{[outstanding_str, incoming_str].compact.join ' and '} commits from "
        else
          result = "up to date with "
        end

        result += "<a class=remote-branch href=\"#{repo_url curr_remote_branch}\">#{curr_remote_branch}</a>"
      end
    end
  end
end