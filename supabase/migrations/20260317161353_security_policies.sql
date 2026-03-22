-- ==========================================
-- PRE-REQUISITE: CREATE BUCKETS
-- ==========================================

-- Membuat bucket untuk foto produk
INSERT INTO
    storage.buckets (id, name, public)
VALUES ('products', 'products', true) ON CONFLICT (id) DO NOTHING;

-- Membuat bucket untuk foto profil user
INSERT INTO
    storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true) ON CONFLICT (id) DO NOTHING;

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
-- 1. Kebijakan Internal (Hanya user yang login di perusahaan yang sama)
CREATE POLICY "Internal profiles visibility" ON public.profiles FOR
SELECT TO authenticated USING (
        id = auth.uid ()
        OR is_superadmin ()
        OR (
            tenant_id = get_my_tenant_id ()
            AND is_admin ()
        )
    );

-- 2. Kebijakan Publik (Untuk Landing Page Sales)
CREATE POLICY "Public sales landing page" ON public.profiles FOR
SELECT TO anon USING (
        role = 'sales'
        AND slug IS NOT NULL
    );

CREATE POLICY "Profiles update" ON public.profiles FOR
UPDATE TO authenticated USING (
    id = auth.uid ()
    OR is_superadmin ()
    OR (
        tenant_id = get_my_tenant_id ()
        AND is_admin ()
    )
)
WITH
    CHECK (
        id = auth.uid ()
        OR is_superadmin ()
        -- Admin hanya boleh menaikkan/menurunkan role di tenant yang sama
        OR (
            tenant_id = get_my_tenant_id ()
            AND is_admin ()
        )
    );

-- Bank Accounts: Private milik masing-masing user
CREATE POLICY "Users manage own bank accounts" ON public.bank_accounts FOR ALL TO authenticated USING (
    profile_id = auth.uid ()
    OR is_superadmin ()
    OR (
        profile_id IN (
            SELECT id
            FROM public.profiles
            WHERE
                tenant_id = get_my_tenant_id ()
        )
        AND is_admin ()
    )
)
WITH
    CHECK (profile_id = auth.uid ());

-- ==========================================
-- 3. POLICIES: MASTER DATA (Katalog)
-- ==========================================

DROP POLICY IF EXISTS "Catalog viewable by everyone" ON public.categories;

DROP POLICY IF EXISTS "Catalog managed by admin" ON public.categories;

-- ✅ SELEKSI PUBLIK: Siapa saja bisa melihat, tapi di aplikasi React wajib difilter berdasarkan tenant_id perusahaan tersebut
CREATE POLICY "Public view categories" ON public.categories FOR
SELECT USING (true);

-- 🔒 MANAJEMEN INTERNAL: Hanya Admin konveksi tersebut (atau Super Admin) yang bisa Tambah/Ubah/Hapus
CREATE POLICY "Tenant admin manage categories" ON public.categories FOR ALL TO authenticated USING (
    (
        tenant_id = get_my_tenant_id ()
        AND is_admin ()
    )
    OR is_superadmin ()
);

DROP POLICY IF EXISTS "Catalog viewable by everyone" ON public.products;

DROP POLICY IF EXISTS "Catalog managed by admin" ON public.products;

-- ✅ SELEKSI PUBLIK: Digunakan oleh Landing page Sales
CREATE POLICY "Public view products" ON public.products FOR
SELECT USING (true);

-- 🔒 MANAJEMEN INTERNAL: Hanya Admin konveksi tersebut yang bisa kelola
CREATE POLICY "Tenant admin manage products" ON public.products FOR ALL TO authenticated USING (
    (
        tenant_id = get_my_tenant_id ()
        AND is_admin ()
    )
    OR is_superadmin ()
);

DROP POLICY IF EXISTS "Catalog viewable by everyone" ON public.product_images;

DROP POLICY IF EXISTS "Catalog managed by admin" ON public.product_images;

-- ✅ SELEKSI PUBLIK: Gambar produk bisa dilihat di Landing Page
CREATE POLICY "Public view product images" ON public.product_images FOR
SELECT USING (true);

-- 🔒 MANAJEMEN INTERNAL: Hanya Admin konveksi yang bisa upload/hapus via relasi produk
CREATE POLICY "Tenant admin manage product images" ON public.product_images FOR ALL TO authenticated USING (
    EXISTS (
        SELECT 1
        FROM public.products
        WHERE
            products.id = product_images.product_id
            AND (
                (
                    products.tenant_id = get_my_tenant_id ()
                    AND is_admin ()
                )
                OR is_superadmin ()
            )
    )
);

-- ==========================================
-- 4. POLICIES: TRANSAKSI (Core Logic)
-- ==========================================

-- 👥 CUSTOMERS
DROP POLICY IF EXISTS "Sales manage own customers" ON public.customers;

CREATE POLICY "Tenant manage own customers" ON public.customers FOR ALL TO authenticated USING (
    is_superadmin ()
    OR (
        tenant_id = get_my_tenant_id ()
        AND (
            sales_id = auth.uid ()
            OR is_admin ()
        )
    )
);

-- 🛒 ORDERS
DROP POLICY IF EXISTS "Tenant manage own orders" ON public.orders;

CREATE POLICY "Tenant strict isolation for orders" ON public.orders FOR ALL TO authenticated USING (
    is_superadmin () -- Superadmin bypass semua
    OR (
        tenant_id = get_my_tenant_id () -- 🔒 Wajib satu tenant!
        AND (
            sales_id = auth.uid ()
            OR is_admin () -- ⚠️ Pastikan is_admin() Anda juga mengecek tenant_id ke depannya
        )
    )
);

-- 🧵 ORDER ITEMS
DROP POLICY IF EXISTS "Manage items via tenant order ownership" ON public.order_items;

CREATE POLICY "Manage items via order visibility" ON public.order_items FOR ALL TO authenticated USING (
    EXISTS (
        SELECT 1
        FROM public.orders
        WHERE
            id = order_items.order_id -- 🔗 Cukup pasangkan ID-nya. RLS tabel Orders yang akan menyaring otomatis!
    )
);

-- 💳 PAYMENTS
DROP POLICY IF EXISTS "Manage payments via order ownership" ON public.payments;

CREATE POLICY "Manage payments via tenant order ownership" ON public.payments FOR ALL TO authenticated USING (
    EXISTS (
        SELECT 1
        FROM public.orders
        WHERE
            id = payments.order_id
            AND (
                is_superadmin ()
                OR (
                    tenant_id = get_my_tenant_id ()
                    AND (
                        sales_id = auth.uid ()
                        OR is_admin ()
                    )
                )
            )
    )
);

-- 📅 PO PERIODS
DROP POLICY IF EXISTS "PO Periods viewable by all" ON public.po_periods;

DROP POLICY IF EXISTS "PO Periods managed by admin" ON public.po_periods;

CREATE POLICY "Tenant view own PO periods" ON public.po_periods FOR
SELECT TO authenticated USING (
        tenant_id = get_my_tenant_id ()
        OR is_superadmin ()
    );

CREATE POLICY "Tenant manage own PO periods" ON public.po_periods FOR ALL TO authenticated USING (
    (
        tenant_id = get_my_tenant_id ()
        AND is_admin ()
    )
    OR is_superadmin ()
);

-- 📈 LEADS
DROP POLICY IF EXISTS "Leads management" ON public.leads;

DROP POLICY IF EXISTS "Public can insert leads" ON public.leads;

CREATE POLICY "Tenant manage own leads" ON public.leads FOR
SELECT TO authenticated USING (
        is_superadmin ()
        OR (
            tenant_id = get_my_tenant_id ()
            AND (
                sales_id = auth.uid ()
                OR is_admin ()
            )
        )
    );

-- Klien/Anon bisa menginput leads dari landing page mana pun (karena field tenant_id akan diikat otomatis di React)
CREATE POLICY "Public insert leads" ON public.leads FOR
INSERT
    TO anon,
    authenticated
WITH
    CHECK (true);

-- ==========================================
-- 5. STORAGE POLICIES (Supabase Storage)
-- ==========================================

-- 👕 BUCKET: products (Katalog konveksi)
DROP POLICY IF EXISTS "Public view product images" ON storage.objects;

DROP POLICY IF EXISTS "Admin manage products images" ON storage.objects;

-- ✅ SELEKSI PUBLIK: Siapa saja bisa melihat gambar kemeja taktikal di Landing Page
CREATE POLICY "Public view product images" ON storage.objects FOR
SELECT TO anon, authenticated USING (bucket_id = 'products');

-- 🔒 MANAJEMEN INTERNAL: Hanya Admin konveksi yang bersangkutan atau Superadmin yang bisa Upload/Hapus
CREATE POLICY "Tenant admin manage product images" ON storage.objects FOR ALL TO authenticated USING (
    bucket_id = 'products'
    AND (
        is_superadmin ()
        OR is_admin () -- 💡 Pada tahap MVP, Anda mengizinkan admin sistem Anda mengunggah ke bucket ini
    )
);

-- 👤 BUCKET: profiles (Avatar Pengguna)
DROP POLICY IF EXISTS "Users manage own avatar" ON storage.objects;

CREATE POLICY "Users manage own avatar" ON storage.objects FOR ALL TO authenticated USING (
    bucket_id = 'profiles'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'profiles'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 💳 BUCKET: payments (Bukti Transfer - Private)
-- ⚠️ Catatan: Bukti transfer tidak boleh publik! Jangan buat bucket ini 'public: true'.
CREATE POLICY "Tenant view and upload payment proofs" ON storage.objects FOR ALL TO authenticated USING (
    bucket_id = 'payments'
    AND (
        is_superadmin ()
        OR is_admin ()
        -- 💡 Kelak Anda bisa mengecek relasi ke tabel Orders untuk membatasi sales mana yang boleh melihat
    )
);

-- ==========================================
-- 6. TENANT POLICIES (Keamanan Data Perusahaan)
-- ==========================================

-- 1. Aktifkan RLS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- 2. Kebijakan SELECT (Dilihat oleh Publik & Karyawan Sendiri)
-- Kenapa 'anon' diizinkan? Karena saat user mengetik konveksiberkah.saas.com di browser,
-- React butuh mengecek ke Supabase apakah tenant ini terdaftar sebelum user login.
CREATE POLICY "Tenants are viewable by anyone" ON public.tenants FOR
SELECT USING (true);

-- 3. Kebijakan UPDATE (Hanya Admin Konveksi itu sendiri atau Super Admin)
CREATE POLICY "Tenants are manageable by own admin or superadmin" ON public.tenants FOR
UPDATE TO authenticated USING (
    id = get_my_tenant_id ()
    AND is_admin ()
    OR is_superadmin ()
)
WITH
    CHECK (
        id = get_my_tenant_id ()
        AND is_admin ()
        OR is_superadmin ()
    );

-- 4. Kebijakan INSERT dan DELETE (Hanya boleh dilakukan oleh Super Admin)
-- Klien konveksi tidak boleh membuat atau menghapus tenant sendiri lewat API Supabase client.
-- Pendaftaran tenant baru harus lewat sistem registrasi terpusat Anda.
CREATE POLICY "Tenants are insertable/deletable by superadmin only" ON public.tenants FOR ALL TO authenticated USING (is_superadmin ())
WITH
    CHECK (is_superadmin ());