require 'spec_helper'

RSpec.describe Html2mdMcpClient::Client do
  let(:transport) { instance_double('Transport') }
  let(:client) { Html2mdMcpClient::Client.new(transport) }

  def stub_connect!
    allow(transport).to receive(:send_request)
      .with(hash_including(method: 'initialize'))
      .and_return(jsonrpc_response(1, initialize_result))
    allow(transport).to receive(:send_notification)
    client.connect!
  end

  describe '#connect!' do
    it 'performs the initialize handshake' do
      expect(transport).to receive(:send_request)
        .with(hash_including(
          jsonrpc: '2.0',
          method: 'initialize',
          params: hash_including(
            protocolVersion: '2025-03-26',
            clientInfo: hash_including(name: 'html2md_mcp_client')
          )
        ))
        .and_return(jsonrpc_response(1, initialize_result))

      expect(transport).to receive(:send_notification)
        .with(hash_including(method: 'notifications/initialized'))

      client.connect!
    end

    it 'stores server_info and capabilities' do
      stub_connect!
      expect(client.server_info).to eq('name' => 'test-server', 'version' => '1.0.0')
      expect(client.capabilities).to eq('tools' => {})
    end

    it 'returns self' do
      stub_connect!
      expect(client).to be_connected
    end

    it 'is idempotent when already connected' do
      stub_connect!
      expect(transport).not_to receive(:send_request)
      client.connect!
    end

    it 'calls start on transport if it responds to start' do
      transport_with_start = instance_double('StdioTransport', start: nil)
      c = Html2mdMcpClient::Client.new(transport_with_start)

      allow(transport_with_start).to receive(:send_request)
        .and_return(jsonrpc_response(1, initialize_result))
      allow(transport_with_start).to receive(:send_notification)

      expect(transport_with_start).to receive(:start)
      c.connect!
    end
  end

  describe '#disconnect!' do
    it 'closes the transport' do
      stub_connect!
      expect(transport).to receive(:close)
      client.disconnect!
      expect(client).not_to be_connected
    end

    it 'does nothing when not connected' do
      expect(transport).not_to receive(:close)
      client.disconnect!
    end

    it 'clears the tools cache' do
      stub_connect!

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(2, { 'tools' => [{ 'name' => 'foo' }] }))

      client.list_tools

      expect(transport).to receive(:close)
      client.disconnect!

      # Reconnect and verify cache is cleared
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'initialize'))
        .and_return(jsonrpc_response(3, initialize_result))
      allow(transport).to receive(:send_notification)
      client.connect!

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(4, { 'tools' => [{ 'name' => 'bar' }] }))

      expect(client.list_tools.first['name']).to eq('bar')
    end
  end

  describe '#list_tools' do
    before { stub_connect! }

    it 'returns tool definitions' do
      tools = [
        { 'name' => 'html_to_markdown', 'description' => 'Convert HTML to Markdown', 'inputSchema' => {} }
      ]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(2, { 'tools' => tools }))

      expect(client.list_tools).to eq(tools)
    end

    it 'caches the result' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .once
        .and_return(jsonrpc_response(2, { 'tools' => [{ 'name' => 'foo' }] }))

      client.list_tools
      client.list_tools
    end

    it 'returns empty array when no tools' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(2, {}))

      expect(client.list_tools).to eq([])
    end

    it 'raises NotConnectedError when not connected' do
      new_client = Html2mdMcpClient::Client.new(transport)
      expect { new_client.list_tools }.to raise_error(Html2mdMcpClient::NotConnectedError)
    end
  end

  describe '#call_tool' do
    before { stub_connect! }

    it 'returns content array' do
      content = [{ 'type' => 'text', 'text' => '# Hello' }]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/call', params: { name: 'my_tool', arguments: { url: 'http://x.com' } }))
        .and_return(jsonrpc_response(2, { 'content' => content }))

      expect(client.call_tool('my_tool', { url: 'http://x.com' })).to eq(content)
    end

    it 'raises ToolError when server signals error' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/call'))
        .and_return(jsonrpc_response(2, {
          'isError' => true,
          'content' => [{ 'type' => 'text', 'text' => 'Something went wrong' }]
        }))

      expect { client.call_tool('bad_tool') }.to raise_error(Html2mdMcpClient::ToolError, /Something went wrong/)
    end

    it 'returns empty array when no content' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/call'))
        .and_return(jsonrpc_response(2, {}))

      expect(client.call_tool('empty_tool')).to eq([])
    end
  end

  describe '#tool_text' do
    before { stub_connect! }

    it 'returns joined text content' do
      content = [
        { 'type' => 'text', 'text' => 'Line 1' },
        { 'type' => 'image', 'data' => 'base64...' },
        { 'type' => 'text', 'text' => 'Line 2' }
      ]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/call'))
        .and_return(jsonrpc_response(2, { 'content' => content }))

      expect(client.tool_text('my_tool')).to eq("Line 1\nLine 2")
    end
  end

  describe '#find_tool' do
    before { stub_connect! }

    it 'returns matching tool definition' do
      tools = [
        { 'name' => 'foo', 'description' => 'Foo tool' },
        { 'name' => 'bar', 'description' => 'Bar tool' }
      ]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(2, { 'tools' => tools }))

      expect(client.find_tool('bar')).to eq({ 'name' => 'bar', 'description' => 'Bar tool' })
    end

    it 'returns nil when not found' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(2, { 'tools' => [] }))

      expect(client.find_tool('missing')).to be_nil
    end
  end

  describe '#list_resources' do
    before { stub_connect! }

    it 'returns resource definitions' do
      resources = [{ 'uri' => 'file:///tmp/data.json', 'name' => 'data.json' }]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'resources/list'))
        .and_return(jsonrpc_response(2, { 'resources' => resources }))

      expect(client.list_resources).to eq(resources)
    end
  end

  describe '#read_resource' do
    before { stub_connect! }

    it 'returns resource contents' do
      contents = [{ 'uri' => 'file:///tmp/data.json', 'text' => '{"key":"value"}' }]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'resources/read', params: { uri: 'file:///tmp/data.json' }))
        .and_return(jsonrpc_response(2, { 'contents' => contents }))

      expect(client.read_resource('file:///tmp/data.json')).to eq(contents)
    end
  end

  describe '#list_prompts' do
    before { stub_connect! }

    it 'returns prompt definitions' do
      prompts = [{ 'name' => 'summarize', 'description' => 'Summarize text' }]

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'prompts/list'))
        .and_return(jsonrpc_response(2, { 'prompts' => prompts }))

      expect(client.list_prompts).to eq(prompts)
    end
  end

  describe '#get_prompt' do
    before { stub_connect! }

    it 'returns prompt result' do
      result = { 'messages' => [{ 'role' => 'user', 'content' => 'Summarize: hello' }] }

      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'prompts/get', params: { name: 'summarize', arguments: { text: 'hello' } }))
        .and_return(jsonrpc_response(2, result))

      expect(client.get_prompt('summarize', { text: 'hello' })).to eq(result)
    end
  end

  describe 'error handling' do
    before { stub_connect! }

    it 'raises ProtocolError on JSON-RPC error response' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_error(2, -32601, 'Method not found'))

      expect { client.list_tools }.to raise_error(Html2mdMcpClient::ProtocolError, /Method not found/)
    end

    it 'raises ProtocolError on ID mismatch' do
      allow(transport).to receive(:send_request)
        .with(hash_including(method: 'tools/list'))
        .and_return(jsonrpc_response(999, { 'tools' => [] }))

      expect { client.list_tools }.to raise_error(Html2mdMcpClient::ProtocolError, /ID mismatch/)
    end
  end
end
