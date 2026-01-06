const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath);

const today = '2026-01-06';

db.serialize(() => {
    // 1. Delete items ENTERED today
    db.run("DELETE FROM pallets WHERE entry_date = ?", [today], function (err) {
        if (err) console.error("Error deleting entries:", err.message);
        else console.log(`Deleted ${this.changes} rows entered on ${today}`);
    });

    // 2. Reset items RETURNED today (that were entered on previous days)
    // If they were entered today, they are already deleted above.
    // This updates older stock that was returned today back to IN_STOCK.
    const sqlReset = `UPDATE pallets 
                      SET status = 'IN_STOCK', return_date = NULL, note = NULL 
                      WHERE return_date = ?`;

    db.run(sqlReset, [today], function (err) {
        if (err) console.error("Error resetting returns:", err.message);
        else console.log(`Reset ${this.changes} items returned on ${today} back to IN_STOCK`);
    });
});

db.close();
