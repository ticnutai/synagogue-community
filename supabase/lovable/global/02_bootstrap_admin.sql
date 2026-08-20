-- ============================================================================
-- GLOBAL · אוניברסלי · להדביק בכל פרויקט Lovable/Supabase
-- ============================================================================
-- יצירת חשבון המנהל הראשוני ושיוך תפקיד admin.
--   שם משתמש (אימייל): jj1212t@gmail.com
--   סיסמה:            CHANGE_ME_BEFORE_RUN
--
-- אין בקובץ הזה שום מזהה פרויקט / URL / publishable key — רק פרטי המנהל.
--
-- ⚠️  חייב לרוץ ב-Lovable (SQL כ-superuser), לא דרך scripts/direct-run.mjs:
--     כדי ליצור את המנהל הראשון אי אפשר להשתמש ב-execute_admin_migration (הוא
--     דורש שכבר תהיה מנהל — ביצה ותרנגולת). לכן מוכנס ישירות ל-auth.users.
--
-- ⚠️  אבטחה: הקובץ מכיל סיסמה בטקסט גלוי וחלשה (6 ספרות), ומאוחסן ב-repo. זה
--     לאתחול בלבד — מומלץ לשנות סיסמה מהאתר אחרי הכניסה הראשונה. הפונקציה
--     admin_create_user של האפליקציה דורשת 8 תווים למשתמשים חדשים; אתחול זה
--     עוקף זאת כי הוא רץ כ-superuser.
--
-- Idempotent: אם החשבון כבר קיים — הסיסמה לא תשתנה, רק תפקיד admin יובטח.
-- דורש: טבלת public.user_roles + enum public.app_role (מסופקים ע"י ה-baseline).
-- ============================================================================

DO $$
DECLARE
  v_email    text := 'jj1212t@gmail.com';
  v_password text := 'CHANGE_ME_BEFORE_RUN';
  v_name     text := 'מנהל';
  v_id       uuid;
BEGIN
  SELECT id INTO v_id FROM auth.users WHERE lower(email) = lower(v_email);

  IF v_id IS NULL THEN
    v_id := gen_random_uuid();

    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, email_change,
      email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      lower(v_email), extensions.crypt(v_password, extensions.gen_salt('bf')), now(),
      NULL, NULL,
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object('name', v_name),
      now(), now(), '', '', '', ''
    );

    RAISE NOTICE 'Created admin auth user % (%).', v_email, v_id;
  ELSE
    RAISE NOTICE 'User % already exists (%); password unchanged, ensuring identity + admin role.', v_email, v_id;
  END IF;

  -- Ensure an email identity exists. GoTrue REQUIRES this for password login;
  -- a user row without it fails login with 500 "Database error querying schema".
  -- Runs for both new and pre-existing users (self-heals accounts created
  -- directly in auth.users without an identity).
  IF NOT EXISTS (
    SELECT 1 FROM auth.identities WHERE user_id = v_id AND provider = 'email'
  ) THEN
    INSERT INTO auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), v_id, v_id::text,
      jsonb_build_object('sub', v_id::text, 'email', lower(v_email), 'email_verified', true),
      'email', NULL, now(), now()
    );
  END IF;

  -- Normalize NULL token columns to '' for this user. GoTrue scans these into
  -- non-nullable Go strings; a NULL (typical for a user created directly in
  -- auth.users) breaks login with 500 "Database error querying schema".
  -- Only touches columns that exist in this GoTrue version (universal).
  DECLARE
    v_col  text;
    v_cols text[] := ARRAY[
      'confirmation_token','recovery_token','email_change','email_change_token_new',
      'email_change_token_current','phone_change','phone_change_token','reauthentication_token'
    ];
  BEGIN
    FOREACH v_col IN ARRAY v_cols LOOP
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='auth' AND table_name='users' AND column_name=v_col) THEN
        EXECUTE format('UPDATE auth.users SET %I = '''' WHERE id = %L AND %I IS NULL',
                       v_col, v_id, v_col);
      END IF;
    END LOOP;
  END;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (v_id, 'admin')
  ON CONFLICT (user_id, role) DO NOTHING;
END $$;

-- כדי לאלץ איפוס סיסמה לחשבון קיים ל-CHANGE_ME_BEFORE_RUN, הרץ פעם אחת (בטל הערה):
-- UPDATE auth.users
--   SET encrypted_password = extensions.crypt('CHANGE_ME_BEFORE_RUN', extensions.gen_salt('bf')),
--       updated_at = now()
-- WHERE lower(email) = lower('jj1212t@gmail.com');
