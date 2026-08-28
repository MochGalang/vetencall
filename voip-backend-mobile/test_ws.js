const WebSocket = require('ws');
const ws = new WebSocket('wss://vetencall.vetencode.com/api/ws', { rejectUnauthorized: false });
ws.on('open', () => { console.log('Node WS CONNECTED'); ws.close(); });
ws.on('error', (e) => console.log('Node WS ERROR', e.message));
ws.on('close', () => console.log('Node WS CLOSED'));
