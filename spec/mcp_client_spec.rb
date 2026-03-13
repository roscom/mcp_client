require 'spec_helper'

RSpec.describe McpClient do
  describe '.http' do
    it 'returns a Client with Http transport' do
      client = McpClient.http('http://localhost:3001/mcp')
      expect(client).to be_a(McpClient::Client)
      expect(client.transport).to be_a(McpClient::Transport::Http)
    end

    it 'passes custom headers to transport' do
      client = McpClient.http('http://localhost:3001/mcp', headers: { 'Authorization' => 'Bearer x' })
      expect(client.transport).to be_a(McpClient::Transport::Http)
    end

    it 'passes client_name option' do
      client = McpClient.http('http://localhost:3001/mcp', client_name: 'searchbird')
      expect(client).to be_a(McpClient::Client)
    end
  end

  describe '.stdio' do
    it 'returns a Client with Stdio transport' do
      client = McpClient.stdio('echo', args: ['test'])
      expect(client).to be_a(McpClient::Client)
      expect(client.transport).to be_a(McpClient::Transport::Stdio)
    end
  end

  describe 'VERSION' do
    it 'is defined' do
      expect(McpClient::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
