-- Full content import for project gicsknanyctuxjfxvmqo (synagogue-community).
--
-- The live database has the complete schema but ZERO content rows. This file
-- seeds the FINAL content state of the source project "בית כנסת אושרה של תורה",
-- i.e. the result of applying its data migrations in order:
--   1. baseline seed        (20260818081728)
--   5. summer schedule       (20260818141000_import_summer_schedule)
--   6. disable shabbat/friday(20260818143000_disable_shabbat_friday_services)
--   7. address update        (20260818145500_update_synagogue_address)
--
-- The source migrations 5/6 are RECONCILIATION scripts (UPDATE ... WHERE label)
-- that assume a pre-existing seed; replaying them against our empty tables would
-- produce a partial, broken schedule. So the already-reconciled FINAL rows are
-- inserted directly instead.
--
-- Each table is guarded by "WHERE NOT EXISTS (SELECT 1 FROM <table>)": it seeds
-- only when the table is still empty, so this file is safe to re-run and will
-- never duplicate rows or overwrite content added later through the admin panel.

BEGIN;

-- Ensure columns exist (no-ops on this project; keeps the file self-contained
-- if ever run against a barer schema).
ALTER TABLE public.shiurim ADD COLUMN IF NOT EXISTS schedule_type text NOT NULL DEFAULT 'weekly';
ALTER TABLE public.settings ADD COLUMN IF NOT EXISTS home_layout text NOT NULL DEFAULT 'classic';

-- settings (singleton) -------------------------------------------------------
INSERT INTO public.settings (name, subtitle, address, city, phone, theme)
SELECT 'בית הכנסת אושר של יהודי', 'קהילה, תורה ותפילה',
       'מצדה 9, בסר 3, קומה 34, בני ברק', 'בני ברק', '', 'navy'
WHERE NOT EXISTS (SELECT 1 FROM public.settings);

-- minyanim (final summer schedule; shabbat + non-shacharit friday kept but
-- inactive, exactly as the source project ends up) ---------------------------
INSERT INTO public.minyanim
  (prayer, label, day_type, time_mode, fixed_time, relative_to, offset_minutes, room, sort_order, active)
SELECT seed.prayer, seed.label, seed.day_type, seed.time_mode, seed.fixed_time::time,
       seed.relative_to, seed.offset_minutes, seed.room, seed.sort_order, seed.active
FROM (VALUES
  -- weekday (all active)
  ('shacharit','שחרית א׳','weekday','fixed','06:15',NULL,0,'אולם מרכזי',10,true),
  ('shacharit','שחרית ב׳','weekday','fixed','07:15',NULL,0,'אולם מרכזי',20,true),
  ('shacharit','שחרית ג׳','weekday','fixed','08:15',NULL,0,'בית מדרש',30,true),
  ('shacharit','שחרית ד׳','weekday','fixed','09:00',NULL,0,'',40,true),
  ('mincha','מנחה 13:30','weekday','fixed','13:30',NULL,0,'בית מדרש',50,true),
  ('mincha','מנחה 14:00','weekday','fixed','14:00',NULL,0,'',60,true),
  ('mincha','מנחה 15:00','weekday','fixed','15:00',NULL,0,'',70,true),
  ('mincha','מנחה 16:00','weekday','fixed','16:00',NULL,0,'',80,true),
  ('mincha','מנחה 17:00','weekday','fixed','17:00',NULL,0,'',90,true),
  ('mincha','מנחה 18:00','weekday','fixed','18:00',NULL,0,'',100,true),
  ('mincha','מנחה 10 דקות לפני השקיעה','weekday','relative',NULL,'sunset',-10,'אולם מרכזי',110,true),
  ('arvit','ערבית בשקיעה','weekday','relative',NULL,'sunset',0,'אולם מרכזי',120,true),
  ('arvit','ערבית 30 דקות אחרי השקיעה','weekday','relative',NULL,'sunset',30,'',130,true),
  ('arvit','ערבית 22:30','weekday','fixed','22:30',NULL,0,'בית מדרש',140,true),
  -- friday (shacharit active; erev-shabbat mincha/arvit kept but inactive)
  ('shacharit','שחרית יום שישי','friday','fixed','08:30',NULL,0,'',10,true),
  ('mincha','מנחה ערב שבת','friday','relative',NULL,'candle',-5,'אולם מרכזי',1,false),
  ('arvit','ערבית ליל שבת','friday','relative',NULL,'sunset',15,'אולם מרכזי',2,false),
  -- shabbat (kept for history, all inactive — synagogue closed on shabbat)
  ('shacharit','שחרית שבת','shabbat','fixed','08:15',NULL,0,'אולם מרכזי',1,false),
  ('mincha','מנחה שבת','shabbat','relative',NULL,'sunset',-60,'אולם מרכזי',2,false),
  ('arvit','ערבית מוצ״ש','shabbat','relative',NULL,'tzeit',5,'אולם מרכזי',3,false)
) AS seed(prayer, label, day_type, time_mode, fixed_time, relative_to, offset_minutes, room, sort_order, active)
WHERE NOT EXISTS (SELECT 1 FROM public.minyanim);

-- announcements --------------------------------------------------------------
INSERT INTO public.announcements (kind, title, body, pinned)
SELECT seed.* FROM (VALUES
  ('mazal_tov','מזל טוב למשפחת כהן','להולדת הבן! הקידוש יתקיים בשבת לאחר התפילה באולם המרכזי.',true),
  ('general','שיעור מיוחד לכבוד ראש חודש','ביום שלישי בשעה 20:30 שיעור מפי הרב, בהשתתפות הציבור.',false)
) AS seed(kind, title, body, pinned)
WHERE NOT EXISTS (SELECT 1 FROM public.announcements);

-- shiur_categories (must precede shiurim: FK category_id) ---------------------
INSERT INTO public.shiur_categories (name, description, sort_order, active)
SELECT 'דף יומי', 'שיעורי הדף היומי המתקיימים בכל יום', 10, true
WHERE NOT EXISTS (SELECT 1 FROM public.shiur_categories WHERE name = 'דף יומי');

-- shiurim (final state: daily daf-yomi trio + two weekly shiurim) -------------
INSERT INTO public.shiurim
  (title, teacher, day_of_week, schedule_type, time_text, location, description, category_id, sort_order, active)
SELECT seed.title, seed.teacher, seed.day_of_week, seed.schedule_type, seed.time_text,
       seed.location, seed.description,
       CASE WHEN seed.use_category
            THEN (SELECT id FROM public.shiur_categories WHERE name = 'דף יומי')
            ELSE NULL END,
       seed.sort_order, true
FROM (VALUES
  ('דף יומי','',0,'daily','08:45','בית מדרש','לפני שחרית ותיקין',true,10),
  ('הלכות שבת','הרב יצחק ברוך',4,'weekly','20:30','אולם מרכזי','שיעור שבועי לכלל הציבור',false,20),
  ('פרשת השבוע','הרב מנחם דוד',6,'weekly','16:30','בית מדרש','בין מנחה לערבית',false,30),
  ('דף יומי','',0,'daily','14:15','','שיעור יומי',true,40),
  ('דף יומי','',0,'daily','15:15','','שיעור יומי',true,50)
) AS seed(title, teacher, day_of_week, schedule_type, time_text, location, description, use_category, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.shiurim);

-- chavrutot ------------------------------------------------------------------
INSERT INTO public.chavrutot (topic, partners, time_text, contact, looking_for_partner, sort_order)
SELECT seed.* FROM (VALUES
  ('גמרא מסכת ברכות','דוד ואבי','ימים א-ה, 20:00','',false,1),
  ('משנה ברורה','מחפשים חברותא','בוקר אחרי שחרית','052-0000000',true,2)
) AS seed(topic, partners, time_text, contact, looking_for_partner, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.chavrutot);

COMMIT;
