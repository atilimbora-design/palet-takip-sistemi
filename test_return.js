
const data = {
    firm_name: 'BEYPILIC',
    pallet_type: 'Plastik',
    count: 2
};

console.log('📤 Gönderilen:', data);

fetch('http://192.168.1.104:3000/api/return', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
})
    .then(res => res.json()) // Cevabı JSON olarak almayı dene
    .then(json => console.log('✅ Sunucu Cevabı:', json))
    .catch(err => console.error('❌ Bağlantı Hatası:', err));
