-- ==========================================
-- PRE-REQUISITE: CREATE BUCKETS
-- ==========================================

-- Membuat bucket untuk foto produk
INSERT INTO
    storage.buckets (id, name, public)
VALUES ('products', 'products', true)
ON CONFLICT (id) DO NOTHING;

-- Membuat bucket untuk foto profil user
INSERT INTO
    storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true)
ON CONFLICT (id) DO NOTHING;

-- Catatan: 'public: true' artinya file di dalamnya bisa diakses via URL publik,
-- namun hak untuk upload/delete tetap diatur oleh RLS Policy yang kita buat sebelumnya.

-- ==========================================
-- 1. ENABLE RLS PADA SEMUA TABEL
-- ==========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.po_periods ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 2. POLICIES: AUTH & PROFILES
-- ==========================================

-- Roles: Semua user authenticated bisa melihat daftar role
CREATE POLICY "Roles are viewable by authenticated users" ON public.roles FOR
SELECT TO authenticated USING (true);

-- Profiles: User bisa lihat & edit data sendiri, Admin bisa lihat semua
CREATE POLICY "Profiles visibility" ON public.profiles FOR
SELECT TO authenticated, anon USING (
        id = auth.uid ()
        OR is_admin ()
        OR (
            role = 'sales'
            AND slug IS NOT NULL
        ) -- Untuk public link sales
    );

CREATE POLICY "Profiles update" ON public.profiles
FOR UPDATE
    TO authenticated USING (
        id = auth.uid ()
        OR is_admin ()
    )
WITH
    CHECK (
        id = auth.uid ()
        OR (
            is_admin ()
            AND (
                role <> 'superadmin'
                OR is_superadmin ()
            )
        )
    );

-- Bank Accounts: Private milik masing-masing user
CREATE POLICY "Users manage own bank accounts" ON public.bank_accounts FOR ALL TO authenticated USING (
    profile_id = auth.uid ()
    OR is_admin ()
)
WITH
    CHECK (profile_id = auth.uid ());

-- ==========================================
-- 3. POLICIES: MASTER DATA (Katalog)
-- ==========================================

-- Categories & Products: Publik bisa lihat, Admin bisa kelola
CREATE POLICY "Catalog viewable by everyone" ON public.categories FOR
SELECT USING (true);

CREATE POLICY "Catalog viewable by everyone" ON public.products FOR
SELECT USING (true);

CREATE POLICY "Catalog viewable by everyone" ON public.product_images FOR
SELECT USING (true);

CREATE POLICY "Catalog managed by admin" ON public.categories FOR ALL TO authenticated USING (is_admin ());

CREATE POLICY "Catalog managed by admin" ON public.products FOR ALL TO authenticated USING (is_admin ());

CREATE POLICY "Catalog managed by admin" ON public.product_images FOR ALL TO authenticated USING (is_admin ());

-- ==========================================
-- 4. POLICIES: TRANSAKSI (Core Logic)
-- ==========================================

-- Customers & Orders: Sales hanya bisa akses datanya sendiri, Admin akses semua
CREATE POLICY "Sales manage own customers" ON public.customers FOR ALL TO authenticated USING (
    sales_id = auth.uid ()
    OR is_admin ()
)
WITH
    CHECK (
        sales_id = auth.uid ()
        OR is_admin ()
    );

CREATE POLICY "Sales manage own orders" ON public.orders FOR ALL TO authenticated USING (
    sales_id = auth.uid ()
    OR is_admin ()
)
WITH
    CHECK (
        sales_id = auth.uid ()
        OR is_admin ()
    );

-- Order Items & Payments: Mengecek akses melalui tabel parent (Orders)
CREATE POLICY "Manage items via order ownership" ON public.order_items FOR ALL TO authenticated USING (
    EXISTS (
        SELECT 1
        FROM public.orders
        WHERE
            id = order_items.order_id
            AND (
                sales_id = auth.uid ()
                OR is_admin ()
            )
    )
);

CREATE POLICY "Manage payments via order ownership" ON public.payments FOR ALL TO authenticated USING (
    EXISTS (
        SELECT 1
        FROM public.orders
        WHERE
            id = payments.order_id
            AND (
                sales_id = auth.uid ()
                OR is_admin ()
            )
    )
);

-- PO Periods: Semua bisa lihat, hanya Admin yang bisa buat/edit
CREATE POLICY "PO Periods viewable by all" ON public.po_periods FOR
SELECT TO authenticated USING (true);

CREATE POLICY "PO Periods managed by admin" ON public.po_periods FOR ALL TO authenticated USING (is_admin ());

-- Leads: Sales lihat miliknya, Publik bisa input (untuk form landing page)
CREATE POLICY "Leads management" ON public.leads FOR
SELECT TO authenticated USING (
        sales_id = auth.uid ()
        OR is_admin ()
    );

CREATE POLICY "Public can insert leads" ON public.leads FOR INSERT TO anon,
authenticated
WITH
    CHECK (true);

-- ==========================================
-- 5. STORAGE POLICIES (Supabase Storage)
-- ==========================================

-- Products Bucket: Publik bisa baca, Admin bisa upload
CREATE POLICY "Public product images" ON storage.objects FOR
SELECT USING (bucket_id = 'products');

CREATE POLICY "Admin manage products images" ON storage.objects FOR ALL USING (
    bucket_id = 'products'
    AND is_admin ()
);

-- Profiles Bucket: User bisa upload fotonya sendiri ke folder miliknya
CREATE POLICY "Users manage own avatar" ON storage.objects FOR ALL TO authenticated USING (
    bucket_id = 'profiles'
    AND (storage.foldername (name)) [1] = auth.uid ()::text
)
WITH
    CHECK (
        bucket_id = 'profiles'
        AND (storage.foldername (name)) [1] = auth.uid ()::text
    );