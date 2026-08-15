const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const startedAt = new Date().toISOString();
let requestCount = 0;

app.get('/', (req, res) => {
  requestCount += 1;
  res.json({
    message: 'Xin chao tu Kubernetes learning lab!',
    pod: process.env.POD_NAME || os.hostname(),
    node: process.env.NODE_NAME || 'unknown',
    podIP: process.env.POD_IP || 'unknown',
    startedAt,
    requestCountOnThisPod: requestCount,
  });
});

app.get('/health', (req, res) => res.send('ok'));

app.listen(PORT, () => {
  console.log(`learn-api listening on port ${PORT}`);
});
