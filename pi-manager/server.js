const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const { Client } = require('ssh2');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const PORT = 3456;

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// Mock Data for Dashboard
let cpuTemp = 45.0;
let logs = [];

// Simulate real-time updates
setInterval(() => {
    // Randomize temp slightly
    cpuTemp = 40 + Math.random() * 15;
    io.emit('stats', { temp: cpuTemp.toFixed(1) });
}, 2000);

// Deploy Endpoint
app.post('/deploy', (req, res) => {
    addLog('Deploy işlemi başlatılıyor...');

    // Simulate Deployment Process
    // In a real scenario, we would use SSH to SCP files from ../backend to the Pi
    setTimeout(() => addLog('Bağlantı kuruluyor (192.168.1.104)...'), 500);
    setTimeout(() => addLog('Dosyalar sıkıştırılıyor...'), 1500);
    setTimeout(() => addLog('Backend servisi durduruluyor...'), 2500);
    setTimeout(() => addLog('Dosyalar kopyalanıyor...'), 3500);
    setTimeout(() => addLog('Backend servisi yeniden başlatılıyor...'), 5000);
    setTimeout(() => {
        addLog('✅ DEPLOY BAŞARILI!');
        res.json({ success: true });
    }, 6000);
});

function addLog(msg) {
    const log = `[${new Date().toLocaleTimeString()}] ${msg}`;
    logs.push(log);
    if (logs.length > 50) logs.shift();
    io.emit('log', log);
}

server.listen(PORT, () => {
    console.log(`Manager Dashboard running at http://localhost:${PORT}`);
});
