-- ==========================================
-- 1. DATA MASTER: ROLES & CATEGORIES
-- ==========================================

-- Seed Roles
INSERT INTO
    public.roles (code, name)
VALUES ('superadmin', 'Super Admin'),
    ('admin', 'Admin'),
    ('sales', 'Sales')
ON CONFLICT (code) DO NOTHING;

-- Seed Categories (Spesifik Konveksi Taktikal)
INSERT INTO
    public.categories (name, slug, description)
VALUES (
        'Kemeja 5.11',
        'kemeja-511',
        'Kemeja taktikal model 5.11 dengan saku rahasia dan ventilasi udara.'
    ),
    (
        'Kemeja Blackhawk',
        'kemeja-blackhawk',
        'Kemeja lapangan dengan desain saku miring khas Blackhawk.'
    ),
    (
        'Kemeja PDL Custom',
        'kemeja-pdl-custom',
        'Kemeja dinas lapangan kustom untuk instansi atau komunitas.'
    ),
    (
        'Celana Cargo Taktikal',
        'celana-cargo',
        'Celana bahan ripstop dengan banyak saku fungsional.'
    )
ON CONFLICT (slug) DO NOTHING;

-- ==========================================
-- 2. DATA PRODUK & HARGA
-- ==========================================

-- Seed Products
INSERT INTO
    public.products (
        category_id,
        name,
        slug,
        price,
        description
    )
SELECT id, 'Kemeja 5.11 Ripstop Tornado', 'kemeja-511-ripstop-tornado', 165000, 'Bahan Ripstop Tornado premium, jahitan double bartek, tersedia warna Khaki, Hitam, dan Hijau Army.'
FROM public.categories
WHERE
    slug = 'kemeja-511'
ON CONFLICT (slug) DO NOTHING;

INSERT INTO
    public.products (
        category_id,
        name,
        slug,
        price,
        description
    )
SELECT id, 'Kemeja Blackhawk Eksklusif', 'kemeja-blackhawk-eksklusif', 155000, 'Desain elegan untuk lapangan maupun kantor. Bahan katun ripstop adem.'
FROM public.categories
WHERE
    slug = 'kemeja-blackhawk'
ON CONFLICT (slug) DO NOTHING;

-- ==========================================
-- 3. PERIODE PRODUKSI (PO PERIOD)
-- ==========================================

INSERT INTO
    public.po_periods (
        name,
        month,
        po_number,
        start_date,
        end_date,
        status
    )
VALUES (
        'Batch Maret Utama',
        '2026-03',
        1,
        '2026-03-01',
        '2026-03-31',
        'open'
    ),
    (
        'Batch April Pre-Order',
        '2026-04',
        1,
        '2026-04-01',
        '2026-04-30',
        'open'
    )
ON CONFLICT DO NOTHING;

-- ==========================================
-- 4. DATA MARKETING (LEADS)
-- ==========================================

-- Catatan: Pastikan Anda sudah memiliki user di auth.users agar profile_id tidak error.
-- Contoh ini berasumsi ada sales dengan ID tertentu (ganti dengan ID user Anda jika perlu).
-- INSERT INTO public.leads (sales_id, product_id, utm_source, utm_campaign, metadata)
-- SELECT
--     id,
--     (SELECT id FROM public.products LIMIT 1),
--     'facebook',
--     'iklan_kemeja_maret',
--     '{"whatsapp_name": "Budi Pengusaha", "note": "Tanya harga grosir 100pcs"}'::jsonb
-- FROM public.profiles WHERE role = 'sales' LIMIT 1;

-- ==========================================
-- 5. DATA PELANGGAN & TRANSAKSI (TESTING FLOW)
-- ==========================================

-- Seed Customer (Linked to Sales)
DO $$ 
DECLARE 
    v_sales_id uuid;
    v_cust_id uuid;
    v_order_id uuid;
    v_po_id uuid;
BEGIN
    -- Ambil ID sales pertama
    SELECT id INTO v_sales_id FROM public.profiles WHERE role = 'sales' LIMIT 1;
    SELECT id INTO v_po_id FROM public.po_periods WHERE status = 'open' LIMIT 1;

    IF v_sales_id IS NOT NULL THEN
        -- Insert Customer
        INSERT INTO public.customers (sales_id, name, phone, address)
        VALUES (v_sales_id, 'Instansi Pemerintah Tasikmalaya', '08123456789', 'Jl. Letnan Harun No. 1')
        RETURNING id INTO v_cust_id;

        -- Insert Order (Tanpa total_price karena akan dihitung Trigger)
        INSERT INTO public.orders (customer_id, sales_id, po_period_id, order_number, include_ppn, ppn_percentage, shipping_cost, shipping_type)
        VALUES (v_cust_id, v_sales_id, v_po_id, 1001, true, 11, 50000, 'ekspedisi')
        RETURNING id INTO v_order_id;

        -- Insert Order Items (Memicu Trigger sync_order_totals)
        INSERT INTO public.order_items (order_id, product_name, quantity, price_per_unit, work_type)
        VALUES 
        (v_order_id, 'Kemeja 5.11 Ripstop Tornado (Custom Logo)', 50, 165000, 'wift'),
        (v_order_id, 'Celana Cargo Taktikal', 20, 185000, 'wift');

        -- Insert Payment (Memicu Trigger update_order_payment_status)
        INSERT INTO public.payments (order_id, amount, payment_method, notes)
        VALUES (v_order_id, 5000000, 'transfer', 'DP Produksi 50 lusin');
    END IF;
END $$;