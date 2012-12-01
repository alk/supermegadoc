#!/usr/bin/env ruby

require './common'

IO.popen("whatis -l -r .", "r") do |f|
  f.each_line do |l|
    l = l.chomp
    next unless l =~ /(.*?) \((.*?)\)\s+-\s+(.*)/
    man = "#{$2}/#{$1}"
    k = "#{man} - #{$3}"
    print_cdb_entry k, "man:#{man}"
  end
end
puts
