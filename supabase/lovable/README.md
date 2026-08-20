# ערכת הרצה ל-Lovable

כל הקבצים כאן הם **SQL טהור** שמדביקים ל-Lovable (SQL editor). אף אחד מהם **לא**
מכיל URL של Supabase, project-ref או publishable key — הם רצים בתוך מסד הנתונים
ולא צריכים אותם.

התיקייה מחולקת לשניים:

```
global/    ← אוניברסלי. מדביקים בכל פרויקט Lovable חדש. מכיל רק את המנהל jj1212t/CHANGE_ME_BEFORE_RUN.
project/   ← ספציפי לפרויקט הזה (בית הכנסת). התוכן והסכימה של האפליקציה הזו.
```

---

## global/ — גלובלי (לכל פרויקט)

| קובץ | מה עושה |
|---|---|
| `01_auth_access_token_hook.sql` | יוצר את `custom_access_token_hook` ל-RBAC. **מתקן את שגיאת ההתחברות 500** ("Database error querying schema"). |
| `02_bootstrap_admin.sql` | יוצר/מוודא את המנהל `jj1212t@gmail.com` עם סיסמה `CHANGE_ME_BEFORE_RUN` ותפקיד admin. |

שני הקבצים **לא** מכילים מזהי פרויקט — רק פרטי המנהל. אוניברסליים, בטוחים
להרצה חוזרת.

## project/ — ספציפי לפרויקט הזה

| קובץ | מה עושה |
|---|---|
| `01_chavruta_requests.sql` | טבלת בקשות חברותא + ה-RPC הציבורי (עם מיסוך פרטי קשר). |
| `02_import_full_content.sql` | כל התוכן: מניינים (לוח קיץ מלא), שיעורים, מודעות, חברותות, הגדרות (כולל כתובת). |

---

## סדר ההתקנה

### לפרויקט הזה (סכימה כבר קיימת, חסר תוכן + התחברות שבורה)

הרץ ב-Lovable לפי הסדר:

```text
1) global/01_auth_access_token_hook.sql     ← מתקן את ה-500, בלי זה אין כניסה
2) global/02_bootstrap_admin.sql            ← מוודא jj1212t כמנהל
3) project/01_chavruta_requests.sql
4) project/02_import_full_content.sql
```

### לפרויקט Supabase חדש לגמרי (מאפס)

```text
0) ../lovable-first-time-setup.sql          ← כל הסכימה + seed בסיסי (רק בפעם הראשונה)
1) global/01_auth_access_token_hook.sql
2) global/02_bootstrap_admin.sql
3) project/02_import_full_content.sql        ← רק אם רוצים את התוכן של בית כנסת זה
```
> ב-baseline כבר כלולה `chavruta_requests`, אז בפרויקט חדש אין צורך בקובץ project/01.

---

## הערות חשובות

1. **הפעלת ה-Auth Hook בפרויקט חדש:** יצירת הפונקציה לבדה לא מפעילה את ה-hook.
   ב-Dashboard: **Authentication → Hooks → Custom Access Token** ובחר את
   `public.custom_access_token_hook`. בפרויקט שכבר מחזיר 500 — ה-hook כבר מופעל,
   כך שהרצת `global/01` מספיקה.

2. **סיסמת המנהל** (`CHANGE_ME_BEFORE_RUN`) חלשה ושמורה בטקסט גלוי ב-repo. מיועדת לאתחול בלבד —
   מומלץ לשנות מהאתר אחרי הכניסה הראשונה. הפונקציה `admin_create_user` של האפליקציה
   דורשת 8 תווים למשתמשים חדשים; האתחול עוקף זאת כי הוא רץ כ-superuser.

3. **למה חייבים להריץ ב-Lovable ולא דרך `scripts/direct-run.mjs`:** ה-runner נכנס
   קודם עם המנהל ואז מריץ. כל עוד ההתחברות שבורה (500), או כל עוד אין מנהל — ה-runner
   לא יכול לעבוד. אחרי שמריצים את `global/01` + `global/02` ב-Lovable וההתחברות
   עובדת, אפשר להריץ את קבצי `project/` גם דרך ה-runner (ראו `MIGRATION_RUNNER_GUIDE.md`).

4. כל הקבצים **idempotent** — בטוח להריץ שוב; לא ידרסו תוכן שהוספת בהמשך.
