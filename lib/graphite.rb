# Basic graphite ruby client based on https://gist.github.com/2893429

require 'socket'

GRAPHITE_SERVER="your.graphite.domain.here"
GRAPHITE_PORT=2003

class Graphite
  def initialize(host, port)
    @host = host || GRAPHITE_SERVER
    @port = port || GRAPHITE_PORT
  end

  def socket
    return @socket if @socket && !@socket.closed?
    @socket = TCPSocket.new(@host, @port)
  end

  def report(key, value, time = Time.now)
    begin
      print "#{key} #{value.to_f} #{time.to_i}\n"

      socket.write("#{key} #{value.to_f} #{time.to_i}\n")
    rescue Errno::EPIPE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED
      @socket = nil
      nil
    end
  end

  def close_socket
    @socket.close if @socket
    @socket = nil
  end
end

class GraphiteStopwatcher < Graphite
  def initialize(prefix, host = nil, port = nil)
    @prefix = prefix || ''
    super host, port
  end

  def _start(name)
    @start_times ||= {}
    @start_times[name] = Time.now if name
  end

  def start(name)
    _start name

    # Automatically stop if given a block
    if block_given?
      yielded_value = yield
      stop name
      yielded_value
    end
  end

  def _stop(name)
    raise "No such timer called #{name}" unless @start_times[name]

    duration = Time.now - @start_times[name]
    report @prefix + name, duration

    @start_times.delete name
    close_socket if @start_times.length == 0
  end

  def stop(name)
    _stop(name)
  end
end

class DualGraphiteStopwatcher < GraphiteStopwatcher
  def initialize(prefix, secondary_prefix, host = nil, port = nil)
    @secondary_prefix = secondary_prefix
    super prefix, host, port
  end

  def start(name)
    _start name
    _start @secondary_prefix + name

    # Automatically stop if given a block
    if block_given?
      yielded_value = yield
      stop name
      yielded_value
    end
  end

  def stop(name)
    _stop name
    _stop @secondary_prefix + name
  end
end

# Quick and dirty tests

# timer = GraphiteStopwatcher.new 'test.ruby.stopwatcher.'

# x = timer.start 'bla' do
#   "funky"
# end
# print "\n", "x:  #{x.inspect}", "\n\n"

# timer = DualGraphiteStopwatcher.new 'test.ruby.stopwatcher.', 'two.'
# x = timer.start 'bla' do
#   "funky"
# end
# print "\n", "x:  #{x.inspect}", "\n\n"

# timer = GraphiteStopwatcher.new 'test.ruby.stopwatcher.'

# timer.start 'test1'
# timer.stop 'test1'

# timer.start 'test2' do
#   sleep 1
# end

# timer.start 'test3' do
#   timer.start 'test4' do
#     timer.start 'test5'
#     sleep 1
#     timer.stop 'test5'
#     sleep 1
#   end
#   sleep 1
# end

# timer = DualGraphiteStopwatcher.new 'test.ruby.dualstopwatcher.', 'extra.'

# timer.start 'test1'
# timer.stop 'test1'

# timer.start 'test2' do
#   sleep 1
# end

# timer.start 'test3' do
#   timer.start 'test4' do
#     timer.start 'test5'
#     sleep 1
#     timer.stop 'test5'
#     sleep 1
#   end
#   sleep 1
# end

