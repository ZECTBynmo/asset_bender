class Hash
  #take keys of hash and transform those to a symbols
  def self.transform_keys_to_symbols(value)
    return value unless value.is_a?(Hash)
    value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
  end
end