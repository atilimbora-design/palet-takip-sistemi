const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath);

db.all("SELECT * FROM pallets LIMIT 20", [], (err, rows) => {
    if (err) console.error(err);
    else console.log(JSON.stringify(rows.map(r => ({ id: r.local_id, entry: r.entry_date, ret: r.return_date, st: r.status })), null, 2));
});

db.close();
