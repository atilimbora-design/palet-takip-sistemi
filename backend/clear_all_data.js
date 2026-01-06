const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
    // Delete ALL rows from pallets table
    db.run("DELETE FROM pallets", [], function (err) {
        if (err) {
            console.error("Error clearing table:", err.message);
        } else {
            console.log(`SUCCESS: Deleted all ${this.changes} rows from 'pallets' table.`);
        }
    });
});

db.close();
