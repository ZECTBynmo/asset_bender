require 'net/http'
require "uri"

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

        raise "Error response from #{url}: #{response.code}" if response.code != "200"

        response.body
    end
end

def fetch_url_with_retries(url, timeouts=[1,2,5])
    retry_count = 0
    exception = nil

    timeouts.each do |timeout| 
        begin
            puts "Retry #{retry_count} for #{url}..."  if retry_count > 0

            result = fetch_url url, timeout
            return result
        rescue StandardError => exception
            retry_count += 1
        end
    end

    raise exception
end