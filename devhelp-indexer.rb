#!/usr/bin/env ruby

require 'common'

dir = ARGV[0] || raise("Need base dir! (e.g. /usr/share/gtk-doc/html)")

Dir.chdir(dir)

#indexes = Dir['**/*.devhelp2']
indexes = IO.popen("find . -follow -name '*.devhelp2'","r") {|f| f.readlines.map {|l| l.chomp}}

def unq(quoted)
  quoted.gsub("&quot;",'"').gsub("&apos;","'").gsub("&amp;","&")
end

indexes.each do |path|
  # REXML is really slow. Just use good-old regexps
  kwlines = IO.readlines(path).grep(/<keyword/)
  dirpath = File.dirname(File.expand_path(path))
  kwlines.each do |l|
    unless l =~ /<keyword\s+type="(.*?)"\s+name="(.*?)"\s+link="(.*?)"\s*\/>/
      STDERR.puts "strange line: #{l}"
      next
    end
    type, name, link = $1, $2, $3
    type, name, link = unq(type), unq(name), unq(link)
    name = name.chomp(" ()")
    if type == "enum" && name[0,5] == "enum "
      name = name[5..-1]
    end
    next if type.empty?
    print_cdb_entry "#{name}:#{type}", "file:///#{dirpath}/#{link}\0devhelp:#{name}"
  end
end

puts
