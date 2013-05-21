require 'net/http'
require 'uri'

module AssetBender
  class FetchError < Error; end

  class DownloadError < Error;
    attr_reader :response

    def initialize(response)
      @response = response
    end
  end

  module HTTPUtils

    include LoggerUtils

    # Fetches a URL (http:// or file://) and returns the body as a string
    # You can optionally set the timeout (which defaults to 2 seconds)
    def fetch_url(url, timeout=2)
      uri = URI.parse url

      if uri.scheme == "file"
        File.open uri.path, 'r' do |f|
          return f.read()
        end
      else
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = http.read_timeout = timeout

        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)

        raise AssetBender::FetchError.new "Error response from #{url}: #{response.code}" if response.code != "200"

        response.body
      end
    end

    # Fetches a URL (http:// or file://) and returns the body as a string.
    # If a timeout or other error occurs, then the URL will be refetched
    # timeouts.length times, where each item in the timeouts array is the
    # lenght of the timeout for that retry.
    #
    # E.g. the default (by not specifying a timeout) is to call once with
    # a timeout of 1 second, a secound time with a timeout of 2 seconds,
    # and lastly with a timeout of 5 seconds.
    def fetch_url_with_retries(url, timeouts=[1,2,5])
      retry_count = 0
      exception = nil

      timeouts.each do |timeout| 
        begin
          logger.warn "Retry #{retry_count} for #{url}..."  if retry_count > 0
          result = fetch_url url, timeout

          return result

        # All of the errors: http://tammersaleh.com/posts/rescuing-net-http-exceptions/
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => exception
          logger.warn("Fetching url (retry = #{retry_count}) #{exception}")
          retry_count += 1
        end
      end

      raise exception
    end

    def download_file(url, destination_path)
        uri = URI.parse url
        downloaded_file = open destination_path, "w"

        was_error = false

        begin
            Net::HTTP.start(uri.host, uri.port) do |http|
                http.request_get(uri.path) do |resp|
                    raise AssetBender::DownloadError.new(resp) unless resp.kind_of? Net::HTTPSuccess

                    resp.read_body do |segment|
                        downloaded_file << segment
                        sleep 0.005
                    end
                end
            end

            downloaded_file
        rescue AssetBender::DownloadError => e
            logger.error "Error downloading #{uri} (#{e.response.code}: #{e.response.message})!" 
            was_error = true
            raise
        rescue
            logger.error "Error downloading #{uri}"
            logger.error $!
            was_error = true
            raise
        ensure
            downloaded_file.close()
            File.delete downloaded_file if was_error
        end
    end
  end


  class HTTPUtilsInstance
    include HTTPUtils
  end

end
