$:.push File.expand_path('../lib', __FILE__)
require 'html2md_mcp_client/version'

Gem::Specification.new do |s|
  s.name        = 'html2md_mcp_client'
  s.version     = Html2mdMcpClient::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Searchbird']
  s.email       = ['dev@searchbird.io']
  s.homepage    = 'https://github.com/roscom/html2md_mcp_client'
  s.summary     = 'Ruby client for the Model Context Protocol (MCP)'
  s.description = 'Connects to MCP servers over HTTP or stdio. Supports tools, resources, and prompts.'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.5'

  s.files       = Dir['lib/**/*'] + %w[Gemfile html2md_mcp_client.gemspec]
  s.test_files  = Dir['spec/**/*']

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'webmock', '~> 3.0'
end
