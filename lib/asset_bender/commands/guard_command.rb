require 'guard'

module AssetBender
  module Commands
    class GuardCommand < BaseCommand

      def start_guard(guard_config)

        begin
          Guard::start guard_config

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
        watcher_pid = fork

        # From https://github.com/guard/listen/issues/105
        if watcher_pid.nil?
          ppid = Process.ppid
          puts "Child #{Process.pid} (from parent #{Process.ppid})"

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
