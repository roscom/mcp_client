require 'spec_helper'

RSpec.describe Html2mdMcpClient do
  describe '.http' do
    it 'returns a Client with Http transport' do
      client = Html2mdMcpClient.http('http://localhost:3001/mcp')
      expect(client).to be_a(Html2mdMcpClient::Client)
      expect(client.transport).to be_a(Html2mdMcpClient::Transport::Http)
    end

    it 'passes custom headers to transport' do
      client = Html2mdMcpClient.http('http://localhost:3001/mcp', headers: { 'Authorization' => 'Bearer x' })
      expect(client.transport).to be_a(Html2mdMcpClient::Transport::Http)
    end

    it 'passes client_name option' do
      client = Html2mdMcpClient.http('http://localhost:3001/mcp', client_name: 'searchbird')
      expect(client).to be_a(Html2mdMcpClient::Client)
    end
  end

  describe '.stdio' do
    it 'returns a Client with Stdio transport' do
      client = Html2mdMcpClient.stdio('echo', args: ['test'])
      expect(client).to be_a(Html2mdMcpClient::Client)
      expect(client.transport).to be_a(Html2mdMcpClient::Transport::Stdio)
    end
  end

  describe 'VERSION' do
    it 'is defined' do
      expect(Html2mdMcpClient::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
