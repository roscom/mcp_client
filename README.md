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

Then `bundle install`.

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

# Find a specific tool
client.find_tool("html_to_markdown")
# => { "name" => "html_to_markdown", "description" => "...", "inputSchema" => {...} }

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

### Docker Transport (Stdio)

Spawn an MCP server inside a Docker container and communicate via stdin/stdout.

```ruby
client = McpClient.stdio("docker", args: ["run", "--rm", "-i", "html2md", "python", "-m", "html2md.server"])
client.connect!

client.tool_text("html_to_markdown", { url: "https://example.com" })
# => "# Conversion Successful\n..."

client.disconnect!
```

This creates a fresh container per connection. The `--rm` flag ensures the container is cleaned up when the session ends. The `-i` flag keeps stdin open, which is required for stdio transport.

### Custom Headers (HTTP)

```ruby
client = McpClient.http("https://mcp.example.com/api", headers: {
  "Authorization" => "Bearer #{token}"
})
```

### Custom Client Name

```ruby
client = McpClient.http("http://localhost:3001/mcp", client_name: "my_app", client_version: "2.0.0")
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

## Error Handling

All errors inherit from `McpClient::Error`:

```ruby
begin
  client.connect!
  client.call_tool("some_tool", { arg: "value" })
rescue McpClient::ConnectionError => e
  # Server unreachable, HTTP error, or process terminated
rescue McpClient::ProtocolError => e
  # JSON-RPC error or invalid response from server
rescue McpClient::ToolError => e
  # Tool executed but returned an error result
rescue McpClient::NotConnectedError => e
  # connect! was not called before making requests
end
```

## API Reference

### Factory Methods

| Method | Description |
|---|---|
| `McpClient.http(url, headers: {}, **opts)` | Create a client with HTTP transport |
| `McpClient.stdio(command, args: [], **opts)` | Create a client with stdio transport |

### Client Methods

| Method | Description |
|---|---|
| `connect!` | Perform the MCP initialize handshake |
| `disconnect!` | Close the transport connection |
| `connected?` | Check connection status |
| `list_tools` | List available tools (cached) |
| `call_tool(name, arguments)` | Call a tool, returns content array |
| `tool_text(name, arguments)` | Call a tool, returns joined text |
| `find_tool(name)` | Find a tool definition by name |
| `list_resources` | List available resources |
| `read_resource(uri)` | Read a resource by URI |
| `list_prompts` | List available prompts |
| `get_prompt(name, arguments)` | Get a prompt by name |
| `server_info` | Server info from the handshake |
| `capabilities` | Server capabilities from the handshake |

## Testing

```
bundle install
bundle exec rspec
```

48 specs covering client lifecycle, tool/resource/prompt operations, HTTP transport (including SSE and session management), stdio transport, and error handling.

## Protocol

Implements the [MCP specification](https://spec.modelcontextprotocol.io) (protocol version `2025-03-26`) using JSON-RPC 2.0. Handles session management, SSE response parsing, and the initialize/initialized handshake automatically.

## License

MIT
