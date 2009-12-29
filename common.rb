
module Kernel
  def print_cdb_entry(key, value)
    print "+#{key.size},#{value.size}:#{key}->#{value}\n"
  end
end
