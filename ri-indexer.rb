#!/usr/bin/env ruby

# Based on fasteri from gpicker by Sergey Avseyev

require './common'

def print_ri(v)
  print_cdb_entry(v, "ri:#{v}")
end

IO.popen("ri --list", "r") do |f|
  f.each_line do |l|
    l.chomp!
    print_ri(l)
  end
end


print_cdb_entry "--extra-args", "--dir-separator='#'"

puts
