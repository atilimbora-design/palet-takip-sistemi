const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
    console.log("Checking data for 2025-12-23...");
    db.all("SELECT local_id, temperature, entry_time, entry_date FROM pallets WHERE entry_date = '2025-12-23' LIMIT 10", (err, rows) => {
        if (err) {
            console.error(err);
        } else {
            console.table(rows);
            if (rows.length === 0) console.log("No records found for this date.");
        }
        db.close();
    });
});
