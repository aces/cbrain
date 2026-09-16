#!/usr/bin/env ruby

require 'yaml'
require 'pry'

def main
  usage if ARGV.size != 2
  path1, path2 = *ARGV
  content1 = YAML.load(File.read(path1))
  content2 = YAML.load(File.read(path2))

  puts path1;
  if content1.keys.size == 1 && content2.keys.size == 1
     top1 = content1.keys.first  # 'en'
     top2 = content2.keys.first  # 'fr'
     content1 = content1[top1]
     content2 = content2[top2]
  end

  newcontent2 = reorder('TOP', content1, content2)
  newcontent2 = { top2 => newcontent2 } if top2

  File.open("#{path2}.reordered","w") do |fh|
    fh.write(to_yaml_double_quoted(newcontent2))
  end

  exit 0
end

def usage
  print <<USAGE
Usage: ymlsync file1.yml file2.yml

This program will read the content of both YML files
and produce in output file2.yml.reordered, where all
the keys of file2.yml have been ordered in the same
order as in file1.yml.

This program is mostly useful for I18N translation
tables, e.g.

  ymlsync en/default.yml  fr/default.yml
USAGE
  exit 2
end

def reorder(where,hash1,hash2)
  keys1 = hash1.keys
  keys2 = hash2.keys
  if keys1.sort != keys2.sort
    puts "Error: Object don't have the same set of keys at level '#{where}':"
    extra1 = keys1-keys2
    extra2 = keys2-keys1
    puts "  In left  YAML file: #{extra1.inspect}" if extra1.size > 0
    puts "  In right YAML file: #{extra2.inspect}" if extra2.size > 0
    exit 2
  end
  out = {}
  keys1.each do |k1|
    val1 = hash1[k1]
    val2 = hash2[k1]
    if val1.class != val2.class
      puts "Error: values of a key are not the same type in '#{where}.#{k1}':"
      puts "  Left  side: #{val1.class.to_s}"
      puts "  Right side: #{val2.class.to_s}"
      exit 2
    end
    if ! val1.is_a?(Hash)
      out[k1] = "#{val2}"
      next
    end
    newval2 = reorder("#{where}.#{k1}", val1, val2)
    out[k1] = newval2
  end
  out
end

def to_yaml_double_quoted(obj)
  ast = Psych.parse_stream(obj.to_yaml)
  ast.grep(Psych::Nodes::Mapping).each do |map|
    map.children.each_slice(2) do |_key, value|
      next unless value.is_a?(Psych::Nodes::Scalar)
      value.style  = Psych::Nodes::Scalar::DOUBLE_QUOTED
      value.plain  = false
      value.quoted = true
    end
  end
  ast.yaml
end

main();
