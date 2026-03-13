# MCP Client

Ruby client for the [Model Context Protocol](https://modelcontextprotocol.io) (MCP). Connects to MCP servers over HTTP or stdio. Supports tools, resources, and prompts.

Requires Ruby 2.5+. No external dependencies.

## Installation

Add to your Gemfile:

```ruby
gem 'mcp_client', github: 'roscom/mcp_client'
```

Or from a local path:

```ruby
gem 'mcp_client', path: '../gems/mcp_client'
```

## Usage

### HTTP Transport

```ruby
client = McpClient.http("http://localhost:3001/mcp")
client.connect!

# List available tools
client.list_tools
# => [{ "name" => "html_to_markdown", "description" => "...", "inputSchema" => {...} }, ...]

# Call a tool (returns content array)
client.call_tool("html_to_markdown", { url: "https://example.com" })
# => [{ "type" => "text", "text" => "# Example\n..." }]

# Call a tool (returns joined text)
client.tool_text("html_to_markdown", { url: "https://example.com" })
# => "# Example\n..."

client.disconnect!
```

### Stdio Transport

Spawns the MCP server as a subprocess and communicates via stdin/stdout.

```ruby
client = McpClient.stdio("npx", args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"])
client.connect!

client.list_tools
client.call_tool("read_file", { path: "/tmp/example.txt" })

client.disconnect!
```

### Custom Headers (HTTP)

```ruby
client = McpClient.http("https://mcp.example.com/api", headers: {
  "Authorization" => "Bearer #{token}"
})
```

### Resources

```ruby
client.list_resources
# => [{ "uri" => "file:///tmp/data.json", "name" => "data.json" }, ...]

client.read_resource("file:///tmp/data.json")
# => [{ "uri" => "file:///tmp/data.json", "text" => "..." }]
```

### Prompts

```ruby
client.list_prompts
client.get_prompt("summarize", { text: "Long article content..." })
```

### Finding a Tool

```ruby
tool = client.find_tool("html_to_markdown")
# => { "name" => "html_to_markdown", "description" => "...", "inputSchema" => {...} }
```

## Error Handling

```ruby
begin
  client.connect!
  client.call_tool("some_tool", { arg: "value" })
rescue McpClient::ConnectionError => e
  # Server unreachable or process terminated
rescue McpClient::ProtocolError => e
  # JSON-RPC error from server
rescue McpClient::ToolError => e
  # Tool returned an error result
rescue McpClient::NotConnectedError => e
  # Forgot to call connect!
end
```

## Protocol

Implements the [MCP specification](https://spec.modelcontextprotocol.io) (protocol version `2025-03-26`) using JSON-RPC 2.0. Handles session management, SSE response parsing, and the initialize/initialized handshake automatically.

## License

MIT
