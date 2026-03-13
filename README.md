# Html2md MCP Client

Ruby client for the [html2md-mcp](https://github.com/sunshad0w/html2md-mcp) server, built on the [Model Context Protocol](https://modelcontextprotocol.io) (MCP). Connects over HTTP or stdio and provides access to the server's HTML-to-Markdown conversion tools, resources, and prompts.

This gem assumes you have a working instance of the html2md-mcp server in place. See the [html2md-mcp repository](https://github.com/sunshad0w/html2md-mcp) for setup instructions.

Requires Ruby 2.5+. No external dependencies.

## Installation

Add to your Gemfile:

```ruby
gem 'html2md_mcp_client', github: 'roscom/html2md_mcp_client'
```

Or from a local path:

```ruby
gem 'html2md_mcp_client', path: '../gems/html2md_mcp_client'
```

Then `bundle install`.

## Usage

### HTTP Transport

```ruby
client = Html2mdMcpClient.http("http://localhost:3001/mcp")
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
client = Html2mdMcpClient.stdio("npx", args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"])
client.connect!

client.list_tools
client.call_tool("read_file", { path: "/tmp/example.txt" })

client.disconnect!
```

### Docker Transport (Stdio)

Spawn an MCP server inside a Docker container and communicate via stdin/stdout.

```ruby
client = Html2mdMcpClient.stdio("docker", args: ["run", "--rm", "-i", "html2md", "python", "-m", "html2md.server"])
client.connect!

client.tool_text("html_to_markdown", { url: "https://example.com" })
# => "# Conversion Successful\n..."

client.disconnect!
```

This creates a fresh container per connection. The `--rm` flag ensures the container is cleaned up when the session ends. The `-i` flag keeps stdin open, which is required for stdio transport.

#### With Playwright and Options

Use `fetch_method: "playwright"` for JavaScript-rendered pages, and pass additional options like `wait_for`, `timeout`, and `include_images`:

```ruby
client = Html2mdMcpClient.stdio("docker", args: ["run", "--rm", "-i", "html2md", "python", "-m", "html2md.server"])
client.connect!

result = client.tool_text("html_to_markdown", {
  url: "https://example.com",
  fetch_method: "playwright",
  wait_for: "load",
  timeout: 60,
  include_images: false
})

client.disconnect!
```

#### html_to_markdown Tool Options

| Option | Type | Default | Description |
|---|---|---|---|
| `url` | string | **required** | URL to convert |
| `include_images` | boolean | `true` | Include images in output |
| `include_tables` | boolean | `true` | Include tables in output |
| `include_links` | boolean | `true` | Include links in output |
| `timeout` | integer | `30` | Request timeout in seconds (5-120) |
| `max_size` | integer | `10485760` | Max download size in bytes (1MB-50MB) |
| `use_cache` | boolean | `false` | Cache the result |
| `cache_ttl` | integer | `3600` | Cache TTL in seconds (60-86400) |
| `fetch_method` | string | `"fetch"` | `"fetch"` (fast) or `"playwright"` (JS-rendered) |
| `browser_type` | string | `"chromium"` | `"chromium"`, `"firefox"`, or `"webkit"` |
| `headless` | boolean | `true` | Run browser headless |
| `wait_for` | string | `"networkidle"` | `"load"`, `"domcontentloaded"`, or `"networkidle"` |
| `use_user_profile` | boolean | `false` | Use browser profile with cookies |
| `return_summary` | boolean | `false` | Return summary instead of full content (for large docs) |
| `max_tokens` | integer | `25000` | Auto-return summary above this token count (1K-100K) |
| `section_id` | string | — | Extract only a section by HTML anchor ID |
| `section_heading` | string | — | Extract only a section by heading text |

### Custom Headers (HTTP)

```ruby
client = Html2mdMcpClient.http("https://mcp.example.com/api", headers: {
  "Authorization" => "Bearer #{token}"
})
```

### Custom Client Name

```ruby
client = Html2mdMcpClient.http("http://localhost:3001/mcp", client_name: "my_app", client_version: "2.0.0")
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

All errors inherit from `Html2mdMcpClient::Error`:

```ruby
begin
  client.connect!
  client.call_tool("some_tool", { arg: "value" })
rescue Html2mdMcpClient::ConnectionError => e
  # Server unreachable, HTTP error, or process terminated
rescue Html2mdMcpClient::ProtocolError => e
  # JSON-RPC error or invalid response from server
rescue Html2mdMcpClient::ToolError => e
  # Tool executed but returned an error result
rescue Html2mdMcpClient::NotConnectedError => e
  # connect! was not called before making requests
end
```

## API Reference

### Factory Methods

| Method | Description |
|---|---|
| `Html2mdMcpClient.http(url, headers: {}, **opts)` | Create a client with HTTP transport |
| `Html2mdMcpClient.stdio(command, args: [], **opts)` | Create a client with stdio transport |

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
