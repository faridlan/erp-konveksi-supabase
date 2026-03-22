-- categories
CREATE TABLE public.categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE, -- 🔑 Tenant ID
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    size_chart_url text,
    created_at timestamptz DEFAULT now(),
    UNIQUE (tenant_id, slug)
);

-- products
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
    category_id uuid REFERENCES public.categories (id) ON DELETE SET NULL,
    name text NOT NULL,
    slug text NOT NULL,
    price numeric,
    image_url text,
    description text,
    size_chart_url text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    UNIQUE (tenant_id, slug)
);

-- product images (gallery)
CREATE TABLE public.product_images (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    product_id uuid REFERENCES public.products (id) ON DELETE CASCADE,
    image_url text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.leads (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
    sales_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products (id) ON DELETE SET NULL,
    utm_source text,
    utm_campaign text,
    metadata jsonb DEFAULT '{}'::jsonb,
    time_spent_seconds integer,
    device_info text,
    created_at timestamptz DEFAULT now()
);