const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) console.error(err.message);
    else console.log('Connected to ' + dbPath);
});

db.serialize(() => {
    // Try adding columns. If they exist, it will throw an error but that's fine.
    console.log('Attempting to add columns...');

    db.run("ALTER TABLE pallets ADD COLUMN temperature TEXT", (err) => {
        if (err) console.log('Temperature column might already exist: ' + err.message);
        else console.log('Added temperature column.');
    });

    db.run("ALTER TABLE pallets ADD COLUMN entry_time TEXT", (err) => {
        if (err) console.log('Entry_time column might already exist: ' + err.message);
        else console.log('Added entry_time column.');
    });

    // Check table info
    db.all("PRAGMA table_info(pallets)", (err, rows) => {
        if (err) console.error(err);
        else {
            console.log('\nFinal Table Schema:');
            console.table(rows);
        }
    });
});

db.close();
