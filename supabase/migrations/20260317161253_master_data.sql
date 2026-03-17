-- categories
CREATE TABLE public.categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    name text NOT NULL,
    slug text UNIQUE NOT NULL,
    description text,
    size_chart_url text,
    created_at timestamptz DEFAULT now()
);

-- products
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    category_id uuid REFERENCES public.categories (id) ON DELETE SET NULL,
    name text NOT NULL,
    slug text UNIQUE NOT NULL,
    price numeric,
    image_url text,
    description text,
    size_chart_url text,
    created_at timestamptz DEFAULT now()
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
    sales_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products (id) ON DELETE SET NULL,
    utm_source text,
    utm_campaign text,
    metadata jsonb DEFAULT '{}'::jsonb,
    time_spent_seconds integer,
    device_info text,
    created_at timestamptz DEFAULT now()
);