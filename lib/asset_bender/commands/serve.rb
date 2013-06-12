require 'guard'

module AssetBender
  module Commands
    class Serve < BaseCommand

      def parse_options
        setup_command_env

        # Only update the projects passed in on the command line (if any).
        # Otherwise, update all the projects in the bender config
        @projects_to_update = @args.map { |p| get_project_by_name_or_path(p) }
        @projects_to_update = ProjectsManager.available_projects if @projects_to_update.empty?
      end

      def run

        begin
          # Watch all the local projects, the bender config folder, and the actual
          # asset bender source (if in contributor mode)
          dirs_to_watch = @projects_to_update.map { |p| p.path }
          dirs_to_watch << '~/.bender/'
          groups = ['asset_bender']

          if ENV['BENDER_DEBUG_RELOAD']
            dirs_to_watch << bender_root
            groups << 'server'
          end

          Guard::start({
            :watchdir => dirs_to_watch,
            :groups => groups
          })

          fork_child_watcher_process

          while Guard::running do
            sleep 0.5
          end
        rescue SignalException
          # puts "SignalException exit!"
          exit(42)
        end

      end

      def fork_child_watcher_process

        # From https://github.com/guard/listen/issues/105
        unless ((pid = fork))
          ppid = Process.ppid

          # puts "Child #{Process.pid} (from parent #{Process.ppid})"
          begin
            trap('SIGINT'){
              %w(
                SIGTERM SIGINT SIGQUIT SIGKILL
              ).each do |signal|

                begin
                  print "\n", "kill via signal:  #{signal.inspect}", "\n\n"
                  Process.kill("-#{ signal }", ppid)
                rescue Object
                  nil
                end

                sleep(rand)
              end
            }

            loop do
              Process.kill(0, ppid)
              sleep(1)
            end
          rescue Object => e
            exit!(0)
          end
        end

      end

    end
  end
end
