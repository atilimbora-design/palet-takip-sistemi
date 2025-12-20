const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const db = require('./database');
const os = require('os');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public')); // Serve the dashboard

// Routes

// 1. Health Check
app.get('/api/status', (req, res) => {
    const interfaces = os.networkInterfaces();
    let ipAddress = 'Unknown';
    for (let name in interfaces) {
        for (let iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                ipAddress = iface.address;
                break;
            }
        }
    }

    res.json({
        status: 'UP',
        message: 'Raspberry Pi Backend is Running',
        ip: ipAddress,
        uptime: os.uptime(),
        timestamp: new Date().toISOString()
    });
});

// 2. Sync / Add Pallets (Receives a list or single item)
app.post('/api/sync', (req, res) => {
    const data = req.body; // Expecting array or single object
    const items = Array.isArray(data) ? data : [data];

    if (items.length === 0) {
        return res.status(400).json({ error: 'No data provided' });
    }

    let successCount = 0;
    let errors = [];

    const stmt = db.prepare(`INSERT OR IGNORE INTO pallets (local_id, firm_name, pallet_type, box_count, vehicle_plate, entry_date, note, status, is_synced) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`);

    db.serialize(() => {
        db.run("BEGIN TRANSACTION");

        items.forEach((item) => {
            stmt.run(
                item.local_id,
                item.firm_name,
                item.pallet_type,
                item.box_count || 0,
                item.vehicle_plate || '',
                item.entry_date,
                item.note || '',
                item.status || 'IN_STOCK',
                1, // is_synced = 1 because it reached the server
                (err) => {
                    if (err) {
                        errors.push({ id: item.local_id, error: err.message });
                    } else {
                        successCount++;
                    }
                }
            );
        });

        db.run("COMMIT", () => {
            stmt.finalize();
            res.json({
                message: 'Sync processing complete',
                received: items.length,
                inserted: successCount,
                errors: errors
            });
        });
    });
});

// 3. Get All Pallets
app.get('/api/pallets', (req, res) => {
    db.all("SELECT * FROM pallets ORDER BY entry_date DESC", [], (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json({
            count: rows.length,
            data: rows
        });
    });
});

// 4. Return Pallets (Mock implementation for returning stock)
// Senaryo 3: Palet İadesi
app.post('/api/return', (req, res) => {
    // Expects { firm_name: 'BEYPILIC', count: 50, pallet_type: 'Tahta'} 
    // This logic might need refinement depending on specific business rules (FIFO vs specific ID)
    // For now, we update the status of N items of that firm and type to 'RETURNED'
    const { firm_name, count, pallet_type } = req.body;

    if (!firm_name || !count || !pallet_type) {
        return res.status(400).json({ error: 'Missing parameters' });
    }

    // Find available pallets
    const sql = `SELECT local_id FROM pallets WHERE firm_name = ? AND pallet_type = ? AND status = 'IN_STOCK' LIMIT ?`;

    db.all(sql, [firm_name, pallet_type, count], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });

        if (rows.length < count) {
            return res.status(400).json({
                error: 'Not enough stock to return',
                requested: count,
                available: rows.length
            });
        }

        const idsToUpdate = rows.map(r => r.local_id);
        const placeholders = idsToUpdate.map(() => '?').join(',');

        const updateSql = `UPDATE pallets SET status = 'RETURNED' WHERE local_id IN (${placeholders})`;

        db.run(updateSql, idsToUpdate, function (err) {
            if (err) return res.status(500).json({ error: err.message });
            res.json({
                message: 'Pallets returned successfully',
                returned_count: this.changes
            });
        });
    });
});

// 5. Delete Pallet
app.delete('/api/pallets/:id', (req, res) => {
    const { id } = req.params;
    db.run("DELETE FROM pallets WHERE local_id = ?", [id], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        if (this.changes === 0) return res.status(404).json({ error: 'Pallet not found' });
        res.json({ message: 'Deleted successfully', id: id });
    });
});

// 6. Update Pallet
app.put('/api/pallets/:id', (req, res) => {
    const { id } = req.params;
    const { firm_name, pallet_type, box_count, vehicle_plate, note } = req.body;

    const sql = `UPDATE pallets SET firm_name = ?, pallet_type = ?, box_count = ?, vehicle_plate = ?, note = ? WHERE local_id = ?`;

    db.run(sql, [firm_name, pallet_type, box_count, vehicle_plate, note, id], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        if (this.changes === 0) return res.status(404).json({ error: 'Pallet not found' });
        res.json({ message: 'Updated successfully', id: id });
    });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Network: http://192.168.1.104:${PORT}/api`);
});
