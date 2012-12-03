#!/usr/bin/env ruby

# Based on fasteri from gpicker by Sergey Avseyev

require './common'

def print_ri(v)
  print_cdb_entry(v, "ri:#{v}")
end

IO.popen("-", "r") do |f|
  unless f
    # child
    require 'rdoc/ri/driver'
    driver  = RDoc::RI::Driver.new
    puts driver.list_known_classes
    puts driver.list_methods_matching('.')
    exit
  else
    # parent
    f.each_line do |l|
      l.chomp!
      next if l.empty?
      print_ri(l)
    end
  end
end

print_cdb_entry "--extra-args", "--dir-separator='#'"

puts
