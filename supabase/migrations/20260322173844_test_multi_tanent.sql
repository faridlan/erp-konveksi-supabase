-- 🏢 1. Buat 2 Tenant (Konveksi) fiktif
INSERT INTO
    public.tenants (id, name, subdomain)
VALUES (
        'aaaa1111-aaaa-1111-aaaa-111111111111',
        'Konveksi Berkah Taktikal',
        'berkah'
    ),
    (
        'bbbb2222-bbbb-2222-bbbb-222222222222',
        'Konveksi Sukses Makmur',
        'sukses'
    ) ON CONFLICT (id) DO NOTHING;

-- 🔑 2. Buat User di auth.users (Mematuhi Foreign Key)
INSERT INTO
    auth.users (id, email, raw_user_meta_data)
VALUES (
        '11111111-1111-1111-1111-111111111111',
        'budi@berkah.com',
        '{"full_name": "Budi Admin Berkah", "role": "admin"}'
    ),
    (
        '22222222-2222-2222-2222-222222222222',
        'siti@sukses.com',
        '{"full_name": "Siti Sales Sukses", "role": "sales"}'
    ) ON CONFLICT (id) DO NOTHING;

-- 🛠️ 3. Update Profil (Mengisi tenant_id secara manual untuk simulasi)
UPDATE public.profiles
SET
    tenant_id = 'aaaa1111-aaaa-1111-aaaa-111111111111',
    role = 'admin'
WHERE
    id = '11111111-1111-1111-1111-111111111111';

UPDATE public.profiles
SET
    tenant_id = 'bbbb2222-bbbb-2222-bbbb-222222222222',
    role = 'sales'
WHERE
    id = '22222222-2222-2222-2222-222222222222';

-- 🛒 4. Buat Order milik Konveksi Berkah (Milik Budi) senilai 50 Juta
INSERT INTO
    public.orders (
        id,
        tenant_id,
        sales_id,
        order_number,
        total_price
    )
VALUES (
        'ffffcccc-cccc-cccc-cccc-cccccccccccc',
        'aaaa1111-aaaa-1111-aaaa-111111111111',
        '11111111-1111-1111-1111-111111111111',
        1001,
        50000000
    ) ON CONFLICT (id) DO NOTHING;