

fetch('http://192.168.1.104:3000/api/pallets')
    .then(res => res.json())
    .then(json => {
        console.log('📦 TOPLAM KAYIT:', json.count);
        console.log('🔍 Örnek Kayıtlar (İlk 10):');
        console.table(json.data.slice(0, 10).map(p => ({
            id: p.local_id.substring(0, 8),
            firm: p.firm_name,
            type: p.pallet_type,
            status: p.status
        })));

        // Stoktakileri Say
        const inStock = json.data.filter(p => p.status === 'IN_STOCK');
        console.log(`✅ Stokta: ${inStock.length}`);

        // İadeleri Say
        const returned = json.data.filter(p => p.status === 'RETURNED');
        console.log(`🔙 İade: ${returned.length}`);
    })
    .catch(err => console.error('Hata:', err));
