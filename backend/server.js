const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const db = require('./database');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

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

    // Use INSERT OR REPLACE to ensure status updates (e.g. reverting a return to in_stock) are applied
    const stmt = db.prepare(`INSERT OR REPLACE INTO pallets (local_id, firm_name, pallet_type, box_count, vehicle_plate, entry_date, note, status, is_synced, temperature, entry_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);

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
                1, // is_synced = 1
                item.temperature || '',
                item.entry_time || '',
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
    // Expects { firm_name: 'BEYPILIC', count: 50, pallet_type: 'Tahta', note: 'İade açıklaması' } 
    const { firm_name, count, pallet_type, note } = req.body;

    if (!firm_name || !count || !pallet_type) {
        return res.status(400).json({ error: 'Missing parameters' });
    }

    // Find available pallets (Type only, FIFO based on local_id/entry order implied by DB)
    // IMPORTANT: specific firm!
    const sql = `SELECT local_id FROM pallets 
                 WHERE firm_name = ?
                 AND pallet_type = ? 
                 AND status = 'IN_STOCK' 
                 ORDER BY entry_date ASC
                 LIMIT ?`;

    db.all(sql, [firm_name, pallet_type, count], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });

        if (rows.length < count) {
            return res.status(400).json({
                error: 'Yeterli stok yok',
                requested: count,
                available: rows.length
            });
        }

        const idsToUpdate = rows.map(r => r.local_id);
        const placeholders = idsToUpdate.map(() => '?').join(',');

        const updateSql = `UPDATE pallets SET status = 'RETURNED', note = ? WHERE local_id IN (${placeholders})`;

        // params for update: note, followed by all ids
        const params = [note || '', ...idsToUpdate];

        db.run(updateSql, params, function (err) {
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
    const { firm_name, pallet_type, box_count, vehicle_plate, note, temperature, entry_time } = req.body;

    const sql = `UPDATE pallets SET firm_name = ?, pallet_type = ?, box_count = ?, vehicle_plate = ?, note = ?, temperature = ?, entry_time = ? WHERE local_id = ?`;

    db.run(sql, [firm_name, pallet_type, box_count, vehicle_plate, note, temperature, entry_time, id], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        if (this.changes === 0) return res.status(404).json({ error: 'Pallet not found' });
        res.json({ message: 'Updated successfully', id: id });
    });
});

// 7. Auth Routes
app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    db.get("SELECT password, avatar FROM users WHERE username = ?", [username], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        if (!row) return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
        if (String(row.password) !== String(password)) return res.status(401).json({ error: 'Hatalı Şifre' });
        res.json({ message: 'Login successful', username, avatar: row.avatar });
    });
});

app.put('/api/auth/update', (req, res) => {
    const { username, newPassword } = req.body;
    if (!newPassword || newPassword.length < 3) return res.status(400).json({ error: 'Şifre çok kısa' });

    db.run("UPDATE users SET password = ? WHERE username = ?", [newPassword, username], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        if (this.changes === 0) return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
        res.json({ message: 'Şifre güncellendi' });
    });
});

// 8. User Management Routes
app.get('/api/users', (req, res) => {
    db.all("SELECT username, avatar FROM users", [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

app.post('/api/users', (req, res) => {
    const { username, password, avatar } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'Eksik bilgi' });

    db.run("INSERT INTO users (username, password, avatar) VALUES (?, ?, ?)", [username, password, avatar || 'default'], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'User created' });
    });
});

app.delete('/api/users/:username', (req, res) => {
    db.run("DELETE FROM users WHERE username = ?", [req.params.username], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'User deleted' });
    });
});

app.put('/api/users/:username', (req, res) => {
    const { password, avatar } = req.body;
    let sql = "UPDATE users SET ";
    let params = [];
    if (password) { sql += "password = ?, "; params.push(password); }
    if (avatar) { sql += "avatar = ?, "; params.push(avatar); }

    if (params.length === 0) return res.json({ message: 'Nothing to update' });

    sql = sql.slice(0, -2); // remove comma
    sql += " WHERE username = ?";
    params.push(req.params.username);

    db.run(sql, params, function (err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'User updated' });
    });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Network: http://192.168.1.104:${PORT}/api`);
});
