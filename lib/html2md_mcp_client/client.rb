require 'json'
require 'securerandom'

module Html2mdMcpClient
  class Client
    JSONRPC_VERSION = '2.0'.freeze
    PROTOCOL_VERSION = '2025-03-26'.freeze

    attr_reader :transport, :server_info, :capabilities

    def initialize(transport, client_name: 'html2md_mcp_client', client_version: Html2mdMcpClient::VERSION)
      @transport = transport
      @client_name = client_name
      @client_version = client_version
      @request_id = 0
      @connected = false
      @tools_cache = nil
    end

    # --- Connection lifecycle ---

    def connect!
      return self if @connected

      @transport.start if @transport.respond_to?(:start)

      result = request('initialize', {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: { name: @client_name, version: @client_version }
      })

      @server_info = result['serverInfo']
      @capabilities = result['capabilities'] || {}

      notify('notifications/initialized')
      @connected = true
      self
    end

    def disconnect!
      return unless @connected
      @transport.close
      @connected = false
      @tools_cache = nil
    end

    def connected?
      @connected
    end

    # --- Tools ---

    # Returns array of tool definitions: [{ "name" => ..., "description" => ..., "inputSchema" => ... }]
    def list_tools
      ensure_connected!
      @tools_cache ||= begin
        result = request('tools/list', {})
        result['tools'] || []
      end
    end

    # Call a tool. Returns the content array.
    # Raises ToolError if the server signals an error.
    def call_tool(name, arguments = {})
      ensure_connected!
      result = request('tools/call', { name: name, arguments: arguments })

      if result['isError']
        texts = Array(result['content']).select { |c| c['type'] == 'text' }.map { |c| c['text'] }
        raise ToolError, "Tool '#{name}' error: #{texts.join('; ')}"
      end

      result['content'] || []
    end

    # Convenience: call a tool and return joined text content.
    def tool_text(name, arguments = {})
      call_tool(name, arguments)
        .select { |c| c['type'] == 'text' }
        .map { |c| c['text'] }
        .join("\n")
    end

    # Find a tool definition by name. Returns nil if not found.
    def find_tool(name)
      list_tools.find { |t| t['name'] == name }
    end

    # --- Resources ---

    def list_resources
      ensure_connected!
      result = request('resources/list', {})
      result['resources'] || []
    end

    def read_resource(uri)
      ensure_connected!
      result = request('resources/read', { uri: uri })
      result['contents'] || []
    end

    # --- Prompts ---

    def list_prompts
      ensure_connected!
      result = request('prompts/list', {})
      result['prompts'] || []
    end

    def get_prompt(name, arguments = {})
      ensure_connected!
      request('prompts/get', { name: name, arguments: arguments })
    end

    private

    def ensure_connected!
      raise NotConnectedError, 'Call connect! before making requests' unless @connected
    end

    def next_id
      @request_id += 1
    end

    def request(method, params)
      payload = {
        jsonrpc: JSONRPC_VERSION,
        id: next_id,
        method: method,
        params: params
      }

      response = @transport.send_request(payload)
      validate_response!(response, payload[:id])
      response['result']
    end

    def notify(method, params = {})
      payload = {
        jsonrpc: JSONRPC_VERSION,
        method: method,
        params: params
      }
      @transport.send_notification(payload)
    end

    def validate_response!(response, expected_id)
      if response['error']
        err = response['error']
        raise ProtocolError, "Server error #{err['code']}: #{err['message']}"
      end

      unless response['id'] == expected_id
        raise ProtocolError, "Response ID mismatch: expected #{expected_id}, got #{response['id']}"
      end
    end
  end
end
