const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Database Setup
const dbPath = process.env.DB_PATH || path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        console.error('Database connection error:', err.message);
    } else {
        console.log('Connected to the SQLite database:', dbPath);
    }
});

// Create Tables
db.serialize(() => {
    // Pallets Table
    db.run(`CREATE TABLE IF NOT EXISTS pallets (
        local_id TEXT PRIMARY KEY,
        firm_name TEXT NOT NULL,
        pallet_type TEXT NOT NULL,
        box_count INTEGER,
        vehicle_plate TEXT,
        entry_date TEXT,
        note TEXT,
        status TEXT DEFAULT 'IN_STOCK',
        is_synced INTEGER DEFAULT 0,
        temperature TEXT,
        entry_time TEXT
    )`, (err) => {
        if (err) {
            console.error('Error creating pallets table:', err.message);
        } else {
            console.log('Pallets table ready (checked).');
        }
    });


    // Users Table (For Password Management)
    db.run(`CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT NOT NULL,
    avatar TEXT DEFAULT 'default'
)`, (err) => {
        if (!err) {
            // Seed Default Users
            const stmt = db.prepare("INSERT OR IGNORE INTO users (username, password, avatar) VALUES (?, ?, ?)");
            stmt.run("admin", "1234", "admin_icon");
            stmt.run("BURAK", "1234", "face_blue");
            stmt.run("BORA", "1234", "face_orange");
            stmt.finalize();
        }
    });

    // Migrations
    db.run("ALTER TABLE pallets ADD COLUMN temperature TEXT", (err) => { });
    db.run("ALTER TABLE pallets ADD COLUMN entry_time TEXT", (err) => { });
    db.run("ALTER TABLE users ADD COLUMN avatar TEXT DEFAULT 'default'", (err) => { });
});

module.exports = db;
