-- chavruta_requests table + public "approved" listing RPC.
--
-- Faithful port of the source project's migrations:
--   20260819113145_a97c85a8-0ddd-4f87-a3ff-55b755490ebc.sql (table + policies)
--   20260819113221_c78e3228-fa69-4211-82b7-6c9d0add98a6.sql (revoke anon read + RPC)
-- Combined here and made idempotent (IF NOT EXISTS / DROP ... IF EXISTS /
-- CREATE OR REPLACE), safe to run against this project even though the schema
-- already exists in the live database (project gicsknanyctuxjfxvmqo).

BEGIN;

CREATE TABLE IF NOT EXISTS public.chavruta_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  topic text NOT NULL,
  level text NOT NULL DEFAULT 'beginner',
  intent text NOT NULL DEFAULT 'learn',
  study_format text NOT NULL DEFAULT 'chavruta',
  availability text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  share_contact boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chavruta_requests_level_check CHECK (level IN ('beginner','intermediate','advanced')),
  CONSTRAINT chavruta_requests_intent_check CHECK (intent IN ('learn','teach','both')),
  CONSTRAINT chavruta_requests_format_check CHECK (study_format IN ('chavruta','group')),
  CONSTRAINT chavruta_requests_status_check CHECK (status IN ('pending','approved','rejected')),
  CONSTRAINT chavruta_requests_contact_check CHECK (btrim(phone) <> '' OR btrim(email) <> '')
);

GRANT INSERT ON public.chavruta_requests TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chavruta_requests TO authenticated;
GRANT ALL ON public.chavruta_requests TO service_role;

ALTER TABLE public.chavruta_requests ENABLE ROW LEVEL SECURITY;

-- Anyone may submit a pending request; nobody but an admin may read the raw
-- table (it holds PII). Public visibility of approved rows is exposed only
-- through the SECURITY DEFINER function below, which masks contact details.
DROP POLICY IF EXISTS "anyone can submit chavruta request" ON public.chavruta_requests;
CREATE POLICY "anyone can submit chavruta request"
  ON public.chavruta_requests FOR INSERT TO anon, authenticated
  WITH CHECK (status = 'pending');

DROP POLICY IF EXISTS "public reads approved chavruta requests" ON public.chavruta_requests;
REVOKE SELECT ON public.chavruta_requests FROM anon;

DROP POLICY IF EXISTS "admin reads all chavruta requests" ON public.chavruta_requests;
CREATE POLICY "admin reads all chavruta requests"
  ON public.chavruta_requests FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "admin updates chavruta requests" ON public.chavruta_requests;
CREATE POLICY "admin updates chavruta requests"
  ON public.chavruta_requests FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "admin deletes chavruta requests" ON public.chavruta_requests;
CREATE POLICY "admin deletes chavruta requests"
  ON public.chavruta_requests FOR DELETE TO authenticated
  USING (public.is_admin());

DROP TRIGGER IF EXISTS chavruta_requests_updated ON public.chavruta_requests;
CREATE TRIGGER chavruta_requests_updated
  BEFORE UPDATE ON public.chavruta_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Public listing: approved rows only, contact details shown only when the
-- requester consented (share_contact). Mirrors ApprovedChavrutaRequest in
-- src/lib/data.ts (omits share_contact/status).
CREATE OR REPLACE FUNCTION public.list_approved_chavruta_requests()
RETURNS TABLE(
  id uuid, name text, topic text, level text, intent text,
  study_format text, availability text, notes text,
  phone text, email text, created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.id, r.name, r.topic, r.level, r.intent, r.study_format,
         r.availability, r.notes,
         CASE WHEN r.share_contact THEN r.phone ELSE '' END,
         CASE WHEN r.share_contact THEN r.email ELSE '' END,
         r.created_at
  FROM public.chavruta_requests r
  WHERE r.status = 'approved'
  ORDER BY r.created_at DESC
$$;

GRANT EXECUTE ON FUNCTION public.list_approved_chavruta_requests() TO anon, authenticated;

COMMIT;
