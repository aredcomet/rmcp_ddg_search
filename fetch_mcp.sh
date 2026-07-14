#!/usr/bin/env python3
import sys
import json
import subprocess
import os

def main():
    if len(sys.argv) < 2:
        print("Usage: ./fetch_mcp.sh <URL>")
        sys.exit(1)
        
    url = sys.argv[1]

    # Ensure binary is built to prevent cargo build output mixing in stdio
    # (stderr redirection handles this, but build beforehand is cleaner)
    subprocess.run(["cargo", "build", "--quiet"], check=True)
    
    # Spawn the MCP server in stdio transport mode
    process = subprocess.Popen(
        ["cargo", "run", "--quiet", "--", "--transport", "stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, # Silence server logging/warnings
        text=True
    )
    
    def send_msg(msg):
        process.stdin.write(json.dumps(msg) + "\n")
        process.stdin.flush()
        
    def read_msg():
        line = process.stdout.readline()
        if not line:
            return None
        return json.loads(line)

    try:
        # 1. Send Initialize Request
        init_req = {
            "jsonrpc": "2.0",
            "method": "initialize",
            "id": 1,
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "cli-test-client", "version": "1.0.0"}
            }
        }
        send_msg(init_req)
        
        # Read initialize response
        read_msg()
        
        # 2. Send Initialized Notification
        initialized_notif = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        }
        send_msg(initialized_notif)
        
        # 3. Call fetch_content tool
        call_req = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": 2,
            "params": {
                "name": "fetch_content",
                "arguments": {
                    "url": url,
                    "max_length": 1000000 
                }
            }
        }
        send_msg(call_req)
        
        # Wait for the response for id: 2
        while True:
            resp = read_msg()
            if not resp:
                print("Error: Connection closed by server.", file=sys.stderr)
                break
                
            if resp.get("id") == 2:
                if "error" in resp:
                    print("MCP Server Error:", resp["error"], file=sys.stderr)
                    sys.exit(1)
                
                result = resp.get("result", {})
                content_list = result.get("content", [])
                
                if content_list and isinstance(content_list, list):
                    for item in content_list:
                        if item.get("type") == "text":
                            print(item.get("text", ""))
                else:
                    # Fallback to printing raw JSON if structure is different
                    print(json.dumps(resp, indent=2))
                break
        
        process.terminate()
    except Exception as e:
        process.terminate()
        print(f"Error communicating with MCP server: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
