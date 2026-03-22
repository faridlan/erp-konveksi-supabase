-- PO Periods

CREATE TABLE public.po_periods (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id uuid REFERENCES public.tenants (id) ON DELETE CASCADE,
    name text NOT NULL,
    month text, -- Format: YYYY-MM
    po_number integer DEFAULT 1 NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status text DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    created_at timestamptz DEFAULT now()
);

-- Customers

CREATE TABLE public.customers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id uuid REFERENCES public.tenants (id) ON DELETE CASCADE,
    sales_id uuid NOT NULL REFERENCES public.profiles (id),
    name text NOT NULL,
    phone text,
    address text,
    created_at timestamptz DEFAULT now()
);

-- Orders
CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    customer_id uuid REFERENCES public.customers (id) ON DELETE CASCADE,
    tenant_id uuid REFERENCES public.tenants (id) ON DELETE CASCADE,
    sales_id uuid NOT NULL REFERENCES public.profiles (id),
    po_period_id uuid REFERENCES public.po_periods (id) ON DELETE SET NULL,
    order_number integer NOT NULL,
    total_price bigint DEFAULT 0,
    amount_paid bigint DEFAULT 0,
    payment_status text DEFAULT 'unpaid', -- unpaid, partial, paid
    include_ppn boolean DEFAULT false,
    ppn_percentage integer DEFAULT 0,
    ppn_amount bigint DEFAULT 0,
    shipping_cost bigint DEFAULT 0,
    shipping_type text DEFAULT 'cod',
    expedition_name text,
    weight_kg numeric,
    status text DEFAULT 'pending',
    created_at timestamptz DEFAULT now()
);

-- Order Items
CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    order_id uuid REFERENCES public.orders (id) ON DELETE CASCADE,
    product_name text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    price_per_unit bigint NOT NULL,
    work_type text DEFAULT 'wift' NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Payments
CREATE TABLE public.payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id uuid REFERENCES public.tenants (id) ON DELETE CASCADE,
    order_id uuid NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
    amount bigint NOT NULL,
    payment_method text, -- misal: 'transfer', 'cash'
    evidence_url text, -- link ke foto bukti transfer di storage
    notes text,
    created_at timestamptz DEFAULT now()
);

-- DRY: Centralized Calculation Function
CREATE OR REPLACE FUNCTION public.sync_order_totals() RETURNS trigger AS $$
DECLARE
    v_order_id uuid;
    v_subtotal bigint;
    v_ppn_pct integer;
    v_ship_cost bigint;
BEGIN
    v_order_id := CASE WHEN TG_TABLE_NAME = 'order_items' THEN coalesce(new.order_id, old.order_id) ELSE new.id END;

    SELECT coalesce(sum(quantity * price_per_unit), 0) INTO v_subtotal FROM public.order_items WHERE order_id = v_order_id;
    SELECT ppn_percentage, shipping_cost INTO v_ppn_pct, v_ship_cost FROM public.orders WHERE id = v_order_id;

    UPDATE public.orders SET 
        ppn_amount = (v_subtotal * v_ppn_pct / 100),
        total_price = v_subtotal + (v_subtotal * v_ppn_pct / 100) + v_ship_cost
    WHERE id = v_order_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger untuk otomatis update status di tabel Orders saat payment masuk
CREATE OR REPLACE FUNCTION public.update_order_payment_status() RETURNS trigger AS $$
DECLARE
    v_total_price bigint;
    v_total_paid bigint;
BEGIN
    SELECT total_price INTO v_total_price FROM public.orders WHERE id = new.order_id;
    SELECT sum(amount) INTO v_total_paid FROM public.payments WHERE order_id = new.order_id;

    UPDATE public.orders SET
        amount_paid = coalesce(v_total_paid, 0),
        payment_status = CASE
            WHEN v_total_paid >= v_total_price THEN 'paid'
            WHEN v_total_paid > 0 THEN 'partial'
            ELSE 'unpaid'
        END
    WHERE id = new.order_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_payment_status 
AFTER INSERT OR UPDATE OR DELETE ON public.payments 
FOR EACH ROW EXECUTE FUNCTION public.update_order_payment_status();

CREATE TRIGGER trg_sync_on_items AFTER INSERT OR UPDATE OR DELETE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.sync_order_totals();

CREATE TRIGGER trg_sync_on_order_params AFTER UPDATE OF ppn_percentage, shipping_cost ON public.orders FOR EACH ROW EXECUTE FUNCTION public.sync_order_totals();