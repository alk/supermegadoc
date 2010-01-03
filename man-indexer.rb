#!/usr/bin/env ruby

require 'common'

ARGV[0] || raise("Need base dir! (e.g. /usr/share/man)")

def process_dir(dir)
  dir = File.expand_path(dir)
  files = IO.popen("find #{dir} -follow -type f -o -type l","r") {|f| f.readlines.map {|l| l.chomp}}

  hash = {}
  files.map do |path|
    next unless path =~ /(?:\A|\/)man(\d+)\/(.+)\.(\d+)(\.(gz|bz2))?\z/
    next unless $1 == $3
    next unless File.readable?(path)
    section, name = $1, $2
    hash["#{section}/#{name}"] = path
  end
  hash
end

hashes = ARGV.map(&self.method(:process_dir))
hash = hashes.reverse.inject({}) do |r,h|
  r.merge(h)
end

hash.each do |k,v|
  print_cdb_entry k, "man-file:#{v}\0man:#{k}"
end

puts
