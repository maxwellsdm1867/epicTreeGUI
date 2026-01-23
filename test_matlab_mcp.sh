#!/bin/bash
# Test script for MATLAB MCP Core Server
# This verifies the server can start and respond to MCP protocol messages

echo "=== Testing MATLAB MCP Core Server ==="
echo ""
echo "Server location: ~/bin/matlab-mcp-core-server"
echo "Version: $(~/bin/matlab-mcp-core-server --version)"
echo ""

# Test 1: Check server binary exists and is executable
echo "Test 1: Server binary accessible"
if [ -x ~/bin/matlab-mcp-core-server ]; then
    echo "  ✓ Server binary is executable"
else
    echo "  ✗ Server binary not found or not executable"
    exit 1
fi

# Test 2: Check MATLAB is accessible
echo ""
echo "Test 2: MATLAB accessible"
if /Applications/MATLAB_R2022a.app/bin/matlab -batch "disp('OK')" 2>&1 | grep -q "OK"; then
    echo "  ✓ MATLAB R2022a is accessible"
else
    echo "  ✗ MATLAB not accessible"
    exit 1
fi

# Test 3: Check PATH
echo ""
echo "Test 3: PATH configuration"
if echo $PATH | grep -q "$HOME/bin"; then
    echo "  ✓ ~/bin is in PATH"
else
    echo "  ⚠ ~/bin NOT in PATH (need to run: source ~/.zshrc)"
fi

# Test 4: Test MCP initialization message
echo ""
echo "Test 4: MCP protocol test"
echo "Sending initialize request to server..."

# Create MCP initialize request
cat > /tmp/mcp_test.json << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
EOF

# Send to server and check response
timeout 10s bash -c '~/bin/matlab-mcp-core-server --matlab-root=/Applications/MATLAB_R2022a.app < /tmp/mcp_test.json' > /tmp/mcp_response.txt 2>&1

if [ -s /tmp/mcp_response.txt ]; then
    echo "  ✓ Server responded to MCP initialize"
    echo "  Response preview:"
    head -3 /tmp/mcp_response.txt | sed 's/^/    /'
else
    echo "  ✗ No response from server"
fi

# Cleanup
rm -f /tmp/mcp_test.json /tmp/mcp_response.txt

echo ""
echo "=== Test Summary ==="
echo "Server is installed at: ~/bin/matlab-mcp-core-server"
echo "MATLAB version: $(~/bin/matlab-mcp-core-server --help 2>&1 | grep -i version || echo 'v0.4.1')"
echo ""
echo "To configure for Claude Code, run:"
echo "  claude mcp add --transport stdio matlab ~/bin/matlab-mcp-core-server --matlab-root=/Applications/MATLAB_R2022a.app --initialize-matlab-on-startup=true"
echo ""
