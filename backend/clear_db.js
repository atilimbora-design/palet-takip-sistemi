const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./pallets.db');

db.serialize(() => {
    db.run("DELETE FROM pallets", (err) => {
        if (err) {
            console.error('Hata:', err);
        } else {
            console.log('🗑️ Veritabanı başarıyla temizlendi! Tüm kayıtlar silindi.');
        }
    });
});

db.close();
