#!/usr/bin/ruby

require 'pp'

require 'rubygems'
require 'hpricot'

require 'common'

def check_module_documentation(path)
  doc = Hpricot(IO.read(path))
  name_candidates = (doc/"body > center + center > h1")
#  pp name_candidates
  if name_candidates.size != 1 || name_candidates[0].children.size != 1 # || !(String === name_candidates[0].children[0])
    return
  end

  module_name = name_candidates[0].children[0].to_s

  funs_hash = {}

  fun_names = (doc/"body > p > a > span[@class=bold_code]")
  fun_names.each do |element|
    fragment_name = element.parent.attributes['name']
    text = element.children[0].to_s
#    pp text
    unless text =~ /\A([^\(]+)\(/ || text =~ /\A([^\(]+)  &#60;/
      STDERR.puts "ooops at #{text}.\nelement is #{element.pretty_inspect}" #\n\ndoc: #{doc.pretty_inspect}"
      next
    end
    name = $1
    if fragment_name =~ /-(\d+)\z/
      name << "/" << $1
    end
    funs_hash[name] = fragment_name.to_s unless funs_hash[name]
  end

  {
    :module => module_name,
    :hash => funs_hash,
    :path => path
  }
end

def process_file(path)
  path = File.expand_path(path)
  STDERR.print "processing #{path}.."
  rv = check_module_documentation(path)
  STDERR.puts(rv ? "ok" : "garbage")
  rv
end

data = ARGV.map do |path|
  if File.directory?(path)
    Dir.chdir(path) do
      Dir['**/*.html'].map do |fpath|
        process_file(fpath)
      end
    end
  else
    process_file(path)
  end
end.flatten.compact

data.each do |modinfo|
  mod_name = modinfo[:module]
  path = modinfo[:path]
  modinfo[:hash].each do |name, hash|
    key = "#{mod_name}:#{name}"
    value = "file://#{path}##{hash}"
    print_cdb_entry key, value
  end
end

print_cdb_entry "--extra-args", "--dir-separator=':'"

puts
