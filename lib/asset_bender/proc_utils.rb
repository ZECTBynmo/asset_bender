module AssetBender
  module ProcUtils
    
    def call_if_proc_otherwise_self thing
      if thing.respond_to? :call
        thing.call
      else
        thing
      end
    end

  end
end