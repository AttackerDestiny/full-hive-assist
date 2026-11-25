// Use the installed MCP SDK to reach the existing local executor core.
// No executor/server process is started or reconfigured by this helper.
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
const serverRoot = process.env.ROBLOX_MCP_SERVER_ROOT || path.join(process.env.USERPROFILE, 'roblox-executor-mcp');
const sdk = path.join(serverRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const { Client } = await import(pathToFileURL(path.join(sdk, 'index.js')));
const { StreamableHTTPClientTransport } = await import(pathToFileURL(path.join(sdk, 'streamableHttp.js')));
const [name, argsPath] = process.argv.slice(2);
if (!name) throw new Error('Usage: node tools/call_roblox_mcp.mjs TOOL [arguments.json]');
const args = argsPath ? JSON.parse(await readFile(argsPath, 'utf8')) : {};
const client = new Client({ name: 'bss-diagnostics', version: '1.0.0' });
try {
    await client.connect(new StreamableHTTPClientTransport(new URL('http://127.0.0.1:16384/mcp')));
    if (args.clientId && !/^[0-9a-f-]{8,}$/i.test(args.clientId)) {
        let matches = [];
        for (let attempt = 0; attempt < 20; attempt++) {
            const discovery = await client.callTool({ name: 'list-clients', arguments: {} });
            const listing = discovery.content?.filter(item => item.type === 'text').map(item => item.text).join('\n') || '';
            matches = listing.split('\n').filter(line => line.includes(` | ${args.clientId} @ `));
            if (matches.length) break;
            await new Promise(resolve => setTimeout(resolve, 250));
        }
        if (matches.length !== 1) throw new Error(`Connected account unavailable or ambiguous: ${args.clientId}`);
        args.clientId = matches[0].trim().split(' | ')[0];
    }
    const result = name === 'tools/list' ? await client.listTools() : await client.callTool({ name, arguments: args });
    console.log(JSON.stringify(result));
    if (result.isError) process.exitCode = 1;
} finally { await client.close(); }
