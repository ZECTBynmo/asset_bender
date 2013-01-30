require 'logger'

module AssetBender
  module LoggerUtils
    def logger
      if @logger.nil?
        @logger = Logger.new STDOUT
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity} [#{datetime.strftime "%Y-%m-%d %H:%M:%S"}] - #{msg}\n"
        end

        @logger.level = Logger::INFO
      end

      @logger
    end

    def logger=(logger)
      @logger = logger
    end

  end
end
