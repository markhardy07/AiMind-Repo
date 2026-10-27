-- Add surrogate identity primary keys to the two rate-limit scratch tables that
-- lack one. Forward-only and idempotent; GENERATED ALWAYS AS IDENTITY backfills
-- existing rows automatically, and inserts that omit `id` continue to work.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recaptcha_rate_limit' AND column_name = 'id'
  ) THEN
    ALTER TABLE public.recaptcha_rate_limit ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.recaptcha_rate_limit'::regclass AND contype = 'p'
  ) THEN
    ALTER TABLE public.recaptcha_rate_limit ADD PRIMARY KEY (id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'lilt_zoom_link_rate_limit' AND column_name = 'id'
  ) THEN
    ALTER TABLE public.lilt_zoom_link_rate_limit ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.lilt_zoom_link_rate_limit'::regclass AND contype = 'p'
  ) THEN
    ALTER TABLE public.lilt_zoom_link_rate_limit ADD PRIMARY KEY (id);
  END IF;
END $$;
