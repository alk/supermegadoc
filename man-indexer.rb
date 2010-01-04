#!/usr/bin/env ruby

require 'common'

ARGV[0] || raise("Need base dir! (e.g. /usr/share/man)")

def process_dir(dir)
  dir = File.expand_path(dir)
  files = IO.popen("find #{dir} -follow -type f -o -type l","r") {|f| f.readlines.map {|l| l.chomp}}

  hash = {}
  files.map do |path|
    next unless path =~ /(?:\A|\/)man(\d)\/(.+)\.(\d[^\.]*)(\.(gz|bz2))?\z/
    raise path unless $1 == $3[0,1]
    next unless File.readable?(path)
    section, name = $3, $2
    hash["#{section}/#{name}"] = path
  end
  hash
end

$lexgrog = false

if `which lexgrog`.size != 0
  STDERR.puts "lexgrog is present. Will add whatis info"
  $lexgrog = true
end

hashes = ARGV.map(&self.method(:process_dir))
hash = hashes.reverse.inject({}) do |r,h|
  r.merge(h)
end

if $lexgrog
  new_hash = {}
  processed_files = {}
  hash.each do |k,v|
    next if processed_files[v]
    processed_files[v] = true
    lines = IO.popen("-") do |f|
      if f # parent
        f.read
      else # child
        # this allows me to avoid shell-quoting v
        exec "lexgrog", "-w", v
      end
    end.split("\n")
    re = /\A#{Regexp.escape(v)}:\s+"(.+)"\s*\z/
    lines.each do |l|
      unless l =~ re
        STDERR.puts "!#{l}"
        new_hash[k] = [k,v]
        next
      end
      line = $1
      section, = k.split('/', 2)
      new_hash["#{section}/#{line}"] = [k,v]
    end
  end
  hash = new_hash
end

hash.each do |k,v|
  if Array === v
    print_cdb_entry k, "man-file:#{v[1]}\0man:#{v[0]}"
  else
    print_cdb_entry k, "man-file:#{v}\0man:#{k}"
  end
end

puts
