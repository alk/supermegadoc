#!/usr/bin/env ruby

require 'common'

ARGV[0] || raise("Need base dir! (e.g. /usr/share/man)")

def process_dir(dir)
  files = IO.popen("cd #{dir} && find . -follow -type f -o -type l","r") {|f| f.readlines.map {|l| l.chomp}}

  files.map do |path|
    next unless path =~ /(?:\A|\/)man(\d+)\/(.+)\.(\d+)(\.(gz|bz2))?\z/
    next unless $1 == $3
    next unless File.readable?(File.expand_path(dir, path))
    section, name = $1, $2
    "#{section}/#{name}"
  end
end

ARGV.map(&self.method(:process_dir)).flatten.uniq.compact.each do |res|
  print_cdb_entry "#{res}", "man:#{res}"
end

puts
