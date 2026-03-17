-- extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

-- roles table
CREATE TABLE public.roles (
    code text PRIMARY KEY,
    name text NOT NULL
);

INSERT INTO
    public.roles (code, name)
VALUES ('superadmin', 'Super Admin'),
    ('admin', 'Admin'),
    ('sales', 'Sales');

-- profiles table
CREATE TABLE public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name text,
    role text DEFAULT 'sales' REFERENCES public.roles (code),
    email text,
    phone_number text,
    slug text UNIQUE,
    image_url text,
    position text,
    bio text,
    meta_pixel_id text,
    password_changed boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.bank_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    profile_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    bank_name text NOT NULL,
    account_number text NOT NULL,
    account_holder text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- functions for security
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'));
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_superadmin() RETURNS boolean AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- trigger handle new user
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, email)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New Sales'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'role'), ''), 'sales'),
    new.email
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();