# DuckDuckGo Search MCP Server (Rust)

A high-performance Model Context Protocol (MCP) server written in Rust using `rmcp` and `scraper`. It provides search, webpage scraping, and host date/time capabilities to LLM clients (such as Claude Desktop, Cursor, and Claude Code).

## Features

- **DuckDuckGo Search**: Search the web and receive formatted results (Title, URL, Snippet) optimized for LLMs.
- **Webpage Content Fetcher**: Download and clean webpage content, stripping HTML tags like `<script>`, `<style>`, `<nav>`, `<header>`, and `<footer>` to extract pure readable text, with pagination support to handle large pages.
- **Current Date/Time Provider**: Return the current date, time, and day of the week on the host machine.
- **Lightweight Transport**: Uses standard I/O (stdio) transport for fast, Zero-Network-Overhead IPC.
- **Logging Integration**: Real-time logging sent directly back to the client using MCP log notifications (printed to `stderr` to prevent protocol corruption on `stdout`).

---

## Tools

### 1. `search`
Search the web using DuckDuckGo.
- **Arguments**:
  - `query` (string, required): The search term.
  - `max_results` (number, optional, default: `10`): Maximum results to retrieve.
  - `region` (string, optional): Region/language code to localize results (e.g. `us-en`, `uk-en`, `de-de`, `jp-ja`, `wt-wt`).

### 2. `fetch_content`
Download and extract readable plain text from a URL.
- **Arguments**:
  - `url` (string, required): The URL to fetch (must start with `http://` or `https://`).
  - `start_index` (number, optional, default: `0`): Character offset for pagination.
  - `max_length` (number, optional, default: `8000`): Maximum characters to return.

### 3. `get_current_date`
Get the current local date and time of the host machine. Useful when the model needs to know today's date, day of the week, or the current time.

---

## Configuration & Environment Variables

The server checks the following environment variables at startup:
- `DDG_SAFE_SEARCH`: DuckDuckGo SafeSearch mode. Options: `STRICT` (Strict filtering), `MODERATE` (Moderate, default), `OFF` (No filtering).
- `DDG_REGION`: Default region/language code for localization (e.g., `us-en`).

---

## Compilation

Build the release binary to ensure maximum performance:
```bash
cargo build --release
```
The optimized executable will be located at:
`./target/release/rmcp_ddg_search`

---

## Adding to `mcp.json`

To integrate this server with your favorite MCP client (such as Cursor or Claude Desktop), add the server definition to your `mcp.json` (or `claude_desktop_config.json`) configuration file.

Replace `/Users/bran/src/play/rmcp_ddg_search` with the absolute path to your project directory.

### Example `mcp.json` Configuration

```json
{
  "mcpServers": {
    "ddg-search": {
      "command": "/Users/bran/src/play/rmcp_ddg_search/target/release/rmcp_ddg_search",
      "args": [
        "--transport",
        "stdio"
      ],
      "env": {
        "DDG_SAFE_SEARCH": "MODERATE",
        "DDG_REGION": "us-en"
      }
    }
  }
}
```

### Config File Locations
- **Claude Desktop**: 
  - MacOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
  - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- **Cursor**: Configure directly in Cursor Settings -> Features -> MCP -> Add New MCP Server (Type: `command`, Command: `/Users/bran/src/play/rmcp_ddg_search/target/release/rmcp_ddg_search --transport stdio`).
