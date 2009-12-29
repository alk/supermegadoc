#!/usr/bin/env ruby

# Based on fasteri from gpicker by Sergey Avseyev

require 'yaml'
begin
  require 'rdoc/ri/descriptions'
  require 'rdoc/markup/to_flow'
rescue LoadError
  require 'rdoc/ri/ri_descriptions'
  require 'rdoc/markup/simple_markup/to_flow'
end
require 'net/http'
require 'fileutils'

require 'common'
require 'pp'

ARGV[0] || raise('I need ri path')

def print_ri(v)
  print_cdb_entry(v, "ri:#{v}")
end

def index_path(path)
  Dir.chdir(path) do

    Dir['**/cdesc*.yaml'].each do |name|
      cdesc = YAML.load(IO.read(name))
      next unless cdesc

      if cdesc.full_name.strip.empty?
        next
      end
      print_ri cdesc.full_name
      
      cdesc.class_methods.each do |method|
        print_ri "#{cdesc.full_name}::#{method.name}"
      end
      cdesc.instance_methods.each do |method|
        print_ri "#{cdesc.full_name}##{method.name}"
      end
    end
  end
end

ARGV.each {|p| index_path(p)}

print_cdb_entry "--extra-args", "--dir-separator='#'"

puts
