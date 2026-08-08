// Minimal test — if this works, Bonto can run our server
const http = require('http');
const port = process.env.PORT || 3000;
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    message: 'ЧАРО server is running!',
    env: process.env.NODE_ENV || 'not set',
    jwt: process.env.JWT_ACCESS_SECRET ? 'set' : 'missing',
    ts: new Date().toISOString()
  }));
});
server.listen(port, () => console.log(`Test server on ${port}`));
