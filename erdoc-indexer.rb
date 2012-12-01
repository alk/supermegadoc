#!/usr/bin/env ruby

require 'pp'

require 'rubygems'
require 'forkoff'
require 'hpricot'
require 'active_support/core_ext'

require './common'

C_MODULES = %w(erl_nif erl_driver ic_clib ic_c_protocol
               erl_set_memory_block erl_eterm ei ei_connect erl_marshal)

def check_module_documentation(path)
  doc = Hpricot(IO.read(path))
  name_candidates = (doc/"body div.innertube > center > h1")
  # pp name_candidates
  if name_candidates.size != 1 || name_candidates[0].children.size != 1 # || !(String === name_candidates[0].children[0])
    return
  end

  module_name = name_candidates[0].children[0].to_s
  return if C_MODULES.include?(module_name)

  funs_hash = {}

  fun_names = (doc/"body div.innertube > p > a > span.bold_code").to_a + (doc/"body div.innertube > p > span.bold_code").to_a
  #p fun_names.length
  module_prefix = module_name + ':'
  fun_names.each do |element|
    fragment_name = element.parent.attributes['name']
    if fragment_name.blank?
      anc = (element.parent)/"a[@name]"
      next if anc.blank?
      fragment_name = anc[0].attributes['name']
      next if fragment_name.blank?
    end
    text = element.children[0].to_s.strip
    next if text.empty?
    # pp text
    unless text =~ /\A([^\(]+)\(/ || text =~ /\A([^\(]+)  &#60;/
      # STDERR.puts "ooops at #{text}.\nelement is #{element.pretty_inspect}" #\n\ndoc: #{doc.pretty_inspect}"
      next
    end

    text = text[module_prefix.length..-1] if text.starts_with?(module_prefix)
    text.gsub!(/\s*[\n\r]\s*/,' ')
    funs_hash[text] = fragment_name.to_s unless funs_hash[text]
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

# pp process_file("/usr/share/doc/erlang-doc/lib/stdlib-1.17.4/doc/html/lists.html")
# exit

data = ARGV.map do |path|
  if File.directory?(path)
    Dir.chdir(path) do
      Dir['**/*.html'].forkoff(:processes => 4) do |fpath|
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
    key = "#{mod_name}/#{name}"
    value = "file://#{path}##{hash}"
    print_cdb_entry key, value
  end
end

print_cdb_entry "--extra-args", "--dir-separator='/'"

puts
