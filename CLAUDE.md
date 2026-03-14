# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ruby gem providing an MCP (Model Context Protocol) client for the html2md-mcp server. Connects over HTTP or stdio transport and exposes tools, resources, and prompts via JSON-RPC 2.0. No runtime dependencies beyond Ruby stdlib (2.5+).

## Commands

```bash
bundle install            # Install dependencies
bundle exec rspec         # Run all tests (48 specs)
bundle exec rspec spec/html2md_mcp_client/client_spec.rb          # Run a single spec file
bundle exec rspec spec/html2md_mcp_client/client_spec.rb:42       # Run a single example by line
gem build html2md_mcp_client.gemspec                               # Build the gem
```

## Architecture

The gem has three layers:

1. **Module entry point** (`lib/html2md_mcp_client.rb`) — Factory methods `Html2mdMcpClient.http(url)` and `Html2mdMcpClient.stdio(command)` that wire up a transport and return a `Client`.

2. **Client** (`lib/html2md_mcp_client/client.rb`) — Protocol-level logic: manages the JSON-RPC request/response cycle, the MCP initialize/initialized handshake, and caches tool listings. All public API methods (`call_tool`, `tool_text`, `list_resources`, `get_prompt`, etc.) live here.

3. **Transports** (`lib/html2md_mcp_client/transport/`) — Two interchangeable transport implementations:
   - `Http` — Uses `Net::HTTP`; handles SSE response parsing, session ID tracking via `Mcp-Session-Id` header.
   - `Stdio` — Spawns a subprocess with `Open3.popen3`; reads JSON-RPC responses line-by-line from stdout, skipping non-JSON output.

   Both transports implement `send_request(payload)` → parsed Hash and `send_notification(payload)` → nil.

**Error hierarchy**: `Error` → `ConnectionError`, `ProtocolError`, `ToolError`, `NotConnectedError` (in `lib/html2md_mcp_client/errors.rb`).

## Testing

Tests use RSpec + WebMock (net connections disabled). Spec structure mirrors `lib/`. The `spec_helper.rb` includes `JsonRpcHelpers` with `stub_mcp_init(url)` for HTTP handshake stubbing and `jsonrpc_response`/`jsonrpc_error` builders. Stdio transport tests mock `Open3.popen3` with `StringIO` objects.

## Releasing

Push a `v*` tag to trigger the GitHub Actions workflow (`.github/workflows/release.yml`) which builds and publishes to RubyGems. Version lives in `lib/html2md_mcp_client/version.rb`.

#### 1. Edit version (e.g. 0.1.0 → 0.2.0)
#### 2. Then:
1. git add lib/html2md_mcp_client/version.rb

2. git commit -m "Bump version to 0.2.0"

3. git tag v0.2.0

4. git push origin master --tags