const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'palet_v2.db');
const db = new sqlite3.Database(dbPath);

const jsonData = {
    "count": 39,
    "data": [
        { "local_id": "fde53b4a-b6a3-4578-9daf-55b7573fd4be", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 70, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "cd3efca1-7b65-4e42-a5f5-598c4fba2c89", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 70, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "129618fa-e52d-4809-ae6f-cf3dd455d899", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 70, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "e9216dc6-45ca-4d29-8d3f-18b3ca708d30", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 70, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "f1c1f8e7-e39e-4c36-a2b5-3beb7ae7c081", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 70, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "dab4831d-9a9c-4279-adf2-faf8a78b62b6", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 16, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "86762720-b219-45aa-b058-bfbd05eed262", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 39, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "57666692-d22c-4905-bec3-b5ace79eeb80", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 23, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "b87bc9c4-a47c-4b62-a426-8af8a71ab16a", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 16, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "669f6257-ddec-4db8-baa8-934530d81324", "firm_name": "ISLAK MENDİL", "pallet_type": "Plastik", "box_count": 1, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "7972b01d-0acc-4d58-88db-b44fa956c274", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 56, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "2760df85-b931-4110-8051-72dc718050f8", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 62, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "2603d951-9da4-4c08-8700-f0cbb4e2567e", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 51, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "0aa0d053-5978-4e9b-b4c9-ad730642a738", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 50, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "3b69c42c-458c-4173-bf0a-b588add5d2ea", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 50, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "ff2c7777-179d-4a6f-adf9-edff64b4f9b0", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 26, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "66c5a5ea-bc3b-4400-91b4-6a6bf9336154", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 47, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "ea4b3a8c-f4af-4818-8055-b7e0063ea5a0", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 55, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "2fb99409-a2da-4e3c-b0f5-dcc97ec50ef2", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 60, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "27db8f9a-e45c-403b-86e3-82c68507aa05", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 33, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "c3687b35-97c0-425f-b3ba-b5062027158b", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 54, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "616ea838-d9df-4eaa-91c1-c04b3cd23063", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 58, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "75386bc9-3492-4f50-876b-7a8f2687a329", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 36, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "4f8ffb5d-3245-4de2-8583-9555a2bf40af", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 60, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "f2f1ca94-40cb-4e94-9e9b-ec64eef6d05d", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 44, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "b077b16b-e81a-4bb5-9373-c423a1ec8cc6", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 35, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "72aa2526-aa37-4c14-ae5e-1931da6b49fa", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 32, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "8c2f3568-0f89-4412-b572-f96dcb038b2e", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 32, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "916620c3-8515-4bd2-9bf2-2dcb7b7c0a01", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 32, "vehicle_plate": "14GH361", "entry_date": "2025-12-23", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "cec657cd-01c4-4897-a31e-861203faf4ee", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 51, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "RETURNED", "is_synced": 1 },
        { "local_id": "70ba65d2-cc03-4542-87cf-572f1a3efbb0", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 51, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "RETURNED", "is_synced": 1 },
        { "local_id": "15ed57d0-7081-477e-9a5f-2be76d454c0d", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 51, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "RETURNED", "is_synced": 1 },
        { "local_id": "51ee6c28-02a7-45cc-adcf-91265c76f383", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 76, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "6b7a2cc9-e926-4775-b2cb-2294e72d2452", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 76, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "69526f67-055f-467d-8043-a8eb1acd8c1d", "firm_name": "METRO", "pallet_type": "Plastik", "box_count": 78, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "RETURNED", "is_synced": 1 },
        { "local_id": "7afeaddd-02df-42d0-91e8-af1cdb1bbe51", "firm_name": "METRO", "pallet_type": "Plastik", "box_count": 78, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "d2d375d9-ef41-420e-a1ff-cfe0b1d1e992", "firm_name": "METRO", "pallet_type": "Plastik", "box_count": 78, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "94c16952-e784-4214-b995-cdcb45e7424e", "firm_name": "METRO", "pallet_type": "Plastik", "box_count": 78, "vehicle_plate": "34ZJ45", "entry_date": "2025-12-22", "note": "", "status": "IN_STOCK", "is_synced": 1 },
        { "local_id": "3059f6a1-685f-483d-8426-4fa5b06bc271", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 26, "vehicle_plate": "44DD", "entry_date": "2025-12-22", "note": "", "status": "IN_STOCK", "is_synced": 1 }
    ]
};

// Filter 23.12.2025
const filtered = jsonData.data.filter(d => d.entry_date === '2025-12-23');
console.log(`Filtered ${filtered.length} records for 23.12.2025.`);

db.serialize(() => {
    // Optional: Clear table first if user wants fresh data only
    db.run("DELETE FROM pallets WHERE entry_date = '2025-12-23'");

    const stmt = db.prepare(`INSERT OR REPLACE INTO pallets (local_id, firm_name, pallet_type, box_count, vehicle_plate, entry_date, note, status, is_synced, temperature, entry_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);

    const random = {
        nextInt: (max) => Math.floor(Math.random() * max),
        nextDouble: () => Math.random()
    };

    const validIndices = Array.from({ length: filtered.length }, (_, i) => i);
    // Shuffle
    for (let i = validIndices.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [validIndices[i], validIndices[j]] = [validIndices[j], validIndices[i]];
    }
    const selectedForTemp = new Set(validIndices.slice(0, 5));

    filtered.forEach((r, i) => {
        // Time
        const totalMinutes = 405 + random.nextInt(63); // 06:45 - 07:48
        const h = Math.floor(totalMinutes / 60);
        const m = totalMinutes % 60;
        const timeStr = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;

        // Temp
        let temp = "";
        if (selectedForTemp.has(i)) {
            const val = -0.8 + random.nextDouble() * (2.4 - (-0.8));
            temp = val.toFixed(1);
        }

        stmt.run(
            r.local_id,
            r.firm_name,
            r.pallet_type,
            r.box_count,
            r.vehicle_plate,
            r.entry_date,
            r.note || '',
            r.status,
            1, // is_synced
            temp,
            timeStr
        );
    });

    stmt.finalize(() => {
        console.log("Import completed.");
        db.close();
    });
});
