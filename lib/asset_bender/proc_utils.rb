module AssetBender
  class ExceededRetriesError < Error; end

  module ProcUtils
    
    def call_if_proc_otherwise_self thing
      if thing.respond_to? :call
        thing.call
      else
        thing
      end
    end

    def retry_up_to(num_tries)
      result = nil
      retry_count = 0

      while retry_count < num_tries and result == nil do
        begin
          result = yield
          
        rescue StandardError => e
          raise AssetBender::ExceededRetriesError.new e if retry_count >= num_tries - 1
        end

        retry_count += 1
      end

      result
    end
  end

  class ProcUtilsInstance
    include ProcUtils
  end

end