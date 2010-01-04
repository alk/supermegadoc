unless String.instance_methods.include?(:bytesize)
  class String
    alias_method :bytesize, :size
  end
end

module Kernel
  def print_cdb_entry(key, value)
    print "+#{key.bytesize},#{value.bytesize}:#{key}->#{value}\n"
  end
end
