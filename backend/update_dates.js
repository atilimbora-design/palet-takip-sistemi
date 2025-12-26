const https = require('https');

const data = {
    "count": 31,
    "data": [
        { "local_id": "f953ffe1-5fef-468b-b288-83a7124a2dca", "firm_name": "METRO", "pallet_type": "Plastik", "box_count": 31, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:09" },
        { "local_id": "f77e4775-11e0-44ba-8135-04c615a03a14", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 60, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:15" },
        { "local_id": "f4ea21a4-a5bb-4fce-a9f6-5422fd298860", "firm_name": "POPEYES", "pallet_type": "Plastik", "box_count": 110, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.2", "entry_time": "07:24" },
        { "local_id": "f4c4305a-1d21-4b4b-a11e-6b1c9577bee5", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:15" },
        { "local_id": "d082e4f5-5942-4765-be7f-83062b543538", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 56, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.4", "entry_time": "07:30" },
        { "local_id": "d0349ddd-33cb-4d21-8aa9-ad55b6d8bbb5", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:14" },
        { "local_id": "cb713a03-d74e-4f3d-95c2-4121cc41c5b3", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 50, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.4", "entry_time": "07:29" },
        { "local_id": "c8d5471f-337b-4e7a-8427-de1f76e1d00d", "firm_name": "POPEYES", "pallet_type": "Plastik", "box_count": 101, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:17" },
        { "local_id": "c112a9a8-4bdb-4d4f-a20b-e2037cb09403", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.4", "entry_time": "07:30" },
        { "local_id": "be5059fd-cd19-47f9-868e-69df29e0e57f", "firm_name": "POPEYES", "pallet_type": "Plastik", "box_count": 100, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.4", "entry_time": "07:23" },
        { "local_id": "ba488b72-8ac7-4fe5-b929-034d7147dfd8", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 36, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:13" },
        { "local_id": "ab6365ab-45df-4962-a34b-33fc3bf8c7b8", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:19" },
        { "local_id": "a3eb14c3-b298-406f-98b0-cad03e3243ab", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 42, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.6", "entry_time": "07:27" },
        { "local_id": "84c15f7b-385b-4916-a546-0ec864faa040", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 52, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:05" },
        { "local_id": "7c346b97-be9f-4c98-b6ef-672033924d4f", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 64, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.4", "entry_time": "07:30" },
        { "local_id": "73012ef3-6b31-49a3-8f2d-b520e9f081e6", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 66, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.6", "entry_time": "07:28" },
        { "local_id": "729501b8-5914-4920-9d19-a176c6760350", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 60, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:05" },
        { "local_id": "6a67c660-a2b1-4846-8f1f-1598b4ff1ba7", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 60, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "0.9", "entry_time": "07:26" },
        { "local_id": "65973f9d-485a-4032-9f45-7a6f13fef239", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 62, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "1.5", "entry_time": "07:25" },
        { "local_id": "5cf88bb5-de15-4090-8d1a-b8992dd452e0", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 69, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:08" },
        { "local_id": "5195c45c-6d08-4575-b16f-4d8300763fb1", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:12" },
        { "local_id": "503b4f6e-e16a-46f7-88b8-92f4c058621f", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 35, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:18" },
        { "local_id": "45c0c435-3fde-4e3d-9d15-d5a766135f8e", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 63, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:09" },
        { "local_id": "425f6a82-8bc0-45ea-ad10-786dd53f59bc", "firm_name": "BEYPILIC", "pallet_type": "Tahta", "box_count": 100, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:13" },
        { "local_id": "36a04513-a656-4729-bee8-2b9885ee524c", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:12" },
        { "local_id": "294e01b5-8677-4c9a-b414-c48458929738", "firm_name": "POPEYES", "pallet_type": "Plastik", "box_count": 114, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:17" },
        { "local_id": "1a98fb23-916d-43fb-bb7c-76a2b6306034", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 64, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:08" },
        { "local_id": "178a424b-75b8-47d9-b707-5ea51295e7af", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 64, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:10" },
        { "local_id": "1436144f-5365-497e-8c38-1d9da793be0b", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:19" },
        { "local_id": "142834f1-fb73-474d-99d4-6f1fde9319cd", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 52, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:10" },
        { "local_id": "05dd1526-bb8a-4886-bba5-c3e999a64376", "firm_name": "BEYPILIC", "pallet_type": "Plastik", "box_count": 40, "vehicle_plate": "14BV077", "entry_date": "2025-12-25", "note": "", "status": "IN_STOCK", "is_synced": 1, "temperature": "", "entry_time": "07:11" }
    ]
};

const TARGET_DATE = '2025-12-26'; // New Date

async function updateRecords() {
    console.log(`Sending ${data.data.length} records to Sync with date ${TARGET_DATE}...`);

    // Modify date
    const updatedData = data.data.map(r => ({
        ...r,
        entry_date: TARGET_DATE
    }));

    const body = JSON.stringify(updatedData);

    const options = {
        hostname: 'paletsayim.atilimgida.com',
        port: 443,
        path: '/api/sync',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': body.length,
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json'
        }
    };

    const req = https.request(options, (res) => {
        let responseBody = '';
        res.on('data', (chunk) => responseBody += chunk);
        res.on('end', () => {
            console.log(`Status: ${res.statusCode}`);
            console.log(`Response: ${responseBody}`);
        });
    });

    req.on('error', (e) => {
        console.error(`Error: ${e.message}`);
    });

    req.write(body);
    req.end();
}

updateRecords();
