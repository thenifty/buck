require 'cocoapods'

podfile = Pod::Podfile.from_file(ARGV[0])

config = Pod::Config.new
sources_manager = Pod::Source::Manager.new(config.repos_dir)
sources = [sources_manager.find_or_create_source_with_url(
  'https://github.com/CocoaPods/Specs.git'
)]

resolver = Pod::Resolver.new(
  Pod::Sandbox.new(config.sandbox_root),
  podfile,
  Molinillo::DependencyGraph.new,
  sources
)

specs_by_target = resolver.resolve
specs = []

specs_by_target.each { |t, ary| specs.concat(ary) }
specs.reject! { |s| s.name =~ /\// }
specs.uniq!
buckfile = ''
local_pods_dir = "#{ARGV[0].gsub('Podfile', '')}Pods"

specs.each do |spec|
  consumer = Pod::Specification::Consumer.new(spec, :ios)
  pod_name = consumer.name
  indent = '  '

  buckfile << "apple_library(\n"
  buckfile << indent << "name = '#{pod_name}',\n"
  buckfile << indent << "deps = #{consumer.dependencies},\n"
  files = nil

  Dir.chdir("#{local_pods_dir}/#{pod_name}") do
    files = Dir.glob(consumer.source_files)

    if consumer.preserve_paths
      files.concat(Dir.glob(consumer.preserve_paths))
    end

    if consumer.public_header_files
      files.concat(Dir.glob(consumer.public_header_files))
    end

    files.map! { |f| File.directory?(f) ? Dir.glob("#{f}/**/*") : f }
    files.map! { |f| "Pods/#{pod_name}/#{f}" }
  end

  headers = files.select{ |f| f =~ /\.h(pp)?$/ }
  objects = files.select{ |f| f =~ /\.m(m)?$|\.cc?(pp)?$|\.swift$/ }

  buckfile << indent << "headers = #{headers},\n"
  buckfile << indent << "srcs = #{objects},\n"
  buckfile << indent << "frameworks = [],\n"
  buckfile << indent << "preprocessor_flags = ['-fobjc-arc'],\n"
  buckfile << indent << "link_style = 'shared'\n"
  buckfile << ")\n\n"
end

buckfile.gsub!(/, /, ",\n")
buckfile.gsub!(/"/, "'")

puts buckfile