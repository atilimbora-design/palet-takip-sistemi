const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Database Setup
const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        console.error('Database connection error:', err.message);
    } else {
        console.log('Connected to the SQLite database: palet_v2.db');
    }
});

// Create Table
db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS pallets (
        local_id TEXT PRIMARY KEY,
        firm_name TEXT NOT NULL,
        pallet_type TEXT NOT NULL,
        box_count INTEGER,
        vehicle_plate TEXT,
        entry_date TEXT,
        note TEXT,
        status TEXT DEFAULT 'IN_STOCK',
        is_synced INTEGER DEFAULT 1,
        temperature TEXT,
        entry_time TEXT
    )`, (err) => {
        if (err) {
            console.error('Error creating table:', err.message);
        } else {
            console.log('Pallets table ready (checked).');
            // Migration for existing tables
            db.run("ALTER TABLE pallets ADD COLUMN temperature TEXT", (e) => { });
            db.run("ALTER TABLE pallets ADD COLUMN entry_time TEXT", (e) => { });
        }
    });
});

module.exports = db;
