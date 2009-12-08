#!/usr/bin/ruby

require 'pp'

require 'rubygems'
require 'hpricot'

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

data = ARGV.map do |path|
  STDERR.print "processing #{path}.."
  rv = check_module_documentation(path)
  STDERR.puts(rv ? "ok" : "garbage")
  rv
end.compact

class String
  def to_elisp
    # hopefully our data needs no escaping
    '"' << self << '"'
  end
end

class Array
  def to_elisp
    '(' << (self.map {|i| i.to_elisp}).join(' ')  << ")"
  end
end

class Symbol
  def to_elisp
    to_s
  end
end

class Hash
  def to_elisp
    # alist syntax
    '(' << self.map {|k,v| '(' << k.to_elisp << " . " << v.to_elisp << ')'}.join(' ') << ')'
  end
end

puts data.to_elisp
