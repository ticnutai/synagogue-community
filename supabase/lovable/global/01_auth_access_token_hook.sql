-- ============================================================================
-- GLOBAL · אוניברסלי · להדביק בכל פרויקט Lovable/Supabase
-- ============================================================================
-- Custom Access Token Hook ל-RBAC. מוסיף claim בשם user_role לכל טוקן, לפי
-- טבלת public.user_roles.
--
-- למה זה קריטי: אם ב-Supabase מוגדר Auth Hook (Authentication → Hooks) שמצביע
-- על public.custom_access_token_hook אבל הפונקציה לא קיימת — כל התחברות מחזירה
-- 500 "Database error querying schema". יצירת הפונקציה כאן מתקנת זאת.
--
-- אין בקובץ הזה שום מזהה פרויקט / URL / publishable key — אוניברסלי לחלוטין.
-- בטוח להרצה חוזרת (CREATE OR REPLACE), ובטוח גם בפרויקט ללא טבלת user_roles
-- (הפונקציה לא תשבור התחברות — היא פשוט לא תוסיף role).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  claims jsonb;
  v_role text;
BEGIN
  -- שליפת התפקיד הבכיר ביותר של המשתמש. עטוף ב-EXCEPTION כדי שהתחברות לעולם
  -- לא תישבר — גם אם הטבלה חסרה או יש שגיאה כלשהי.
  BEGIN
    SELECT ur.role::text INTO v_role
    FROM public.user_roles ur
    WHERE ur.user_id = (event->>'user_id')::uuid
    ORDER BY CASE ur.role::text
               WHEN 'admin'  THEN 0
               WHEN 'gabbai' THEN 1
               ELSE 2
             END
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;

  claims := COALESCE(event->'claims', '{}'::jsonb);
  claims := jsonb_set(claims, '{user_role}', COALESCE(to_jsonb(v_role), 'null'::jsonb));
  event  := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;

-- GoTrue מריץ את ה-hook תחת התפקיד supabase_auth_admin — חייב הרשאות מתאימות.
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated, anon, public;

-- הרשאת קריאה ל-user_roles (רק אם הטבלה קיימת — שומר על אוניברסליות).
DO $$
BEGIN
  IF to_regclass('public.user_roles') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.user_roles TO supabase_auth_admin';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- הערה להפעלה בפרויקט חדש: יצירת הפונקציה לבדה לא מפעילה את ה-hook. ב-Dashboard:
--   Authentication → Hooks → Custom Access Token → בחר public.custom_access_token_hook
-- בפרויקט שכבר מחזיר 500 — ה-hook כבר מופעל, כך שיצירת הפונקציה מספיקה לתיקון.
-- ----------------------------------------------------------------------------
