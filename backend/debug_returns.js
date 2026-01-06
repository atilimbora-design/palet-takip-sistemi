const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath);

console.log("Checking for any RETURNED items...");
db.all("SELECT local_id, status, return_date FROM pallets WHERE status = 'RETURNED' LIMIT 20", [], (err, rows) => {
    if (err) console.error(err);
    else console.log(JSON.stringify(rows, null, 2));
});

db.close();
