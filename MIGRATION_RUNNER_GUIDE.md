# 🚀 מדריך הרצת מיגרציות — synagogue-community

## מה זה עושה?

הכלי מריץ SQL על Supabase דרך פונקציית RPC בשם `execute_admin_migration` (מוגדרת ב-DB עצמו,
לא Edge Function). הוא מתחבר עם משתמש אדמין קיים, מקבל טוקן גישה, ומריץ את הפקודה דרך
`/rest/v1/rpc/execute_admin_migration`.

בפרויקט הזה הכלי הרשמי הוא:

```text
scripts/direct-run.mjs
```

הוא נעול (hardcoded) לפרויקט Supabase הזה בלבד — `gicsknanyctuxjfxvmqo` — ומסרב לרוץ על כל
פרויקט אחר.

## שלב 1: כניסה לתיקיית הפרויקט

```powershell
cd "C:\Users\jj121\synagogue-community"
```

## שלב 2: הרצת מיגרציה מקובץ SQL

```powershell
node scripts/direct-run.mjs file "supabase/migrations/20260820114504_4f306565-3d82-4123-a0d5-fdb6d7216636.sql"
```

זה השימוש היחיד הנתמך להרצת מיגרציה.

## שלב 3: צפייה בהיסטוריית מיגרציות

```powershell
node scripts/direct-run.mjs history
```

מציג רשימה של מיגרציות שהורצו בעבר (שם, הצלחה/כישלון, מספר פקודות, זמן הרצה), מתוך טבלת
`migration_logs`.

## איך מזינים פרטי אדמין?

הכלי דורש `ADMIN_EMAIL` ו-`ADMIN_PASSWORD` של משתמש שמוגדר כ-`admin` בטבלת `user_roles` בפרויקט
הזה. אין ברירת מחדל — יש להגדיר את שניהם, למשל:

```powershell
$env:ADMIN_EMAIL="the-real-admin-email@example.com"
$env:ADMIN_PASSWORD="the-real-admin-password"
node scripts/direct-run.mjs file "supabase/migrations/<file>.sql"
```

ניתן גם לשים אותם בקובץ `.env.migrations.local` בשורש הפרויקט (לא ב-git):

```text
ADMIN_EMAIL=the-real-admin-email@example.com
ADMIN_PASSWORD=the-real-admin-password
```

> משתני `MIGRATION_ADMIN_EMAIL` / `MIGRATION_ADMIN_PASSWORD` נתמכים גם הם כשם חלופי.

## פקודות נתמכות בכלי הזה

הכלי תומך **בשתי פקודות בלבד**:

1. `file <path-to-sql-file>` — מריץ את קובץ ה-SQL כמיגרציה, כאשר הנתיב חייב להיות בתוך
   `supabase/migrations/`.
2. `history` — מציג את היסטוריית המיגרציות שהורצו.

אין פקודת `sql "..."` להרצת SQL חופשי — כל הרצה חייבת לצאת מקובץ בתוך `supabase/migrations/`.

## איפה שמים קבצי מיגרציה?

```text
supabase/migrations/
```

מוסכמת שם קובץ (מבוססת חותמת זמן, כמו קובץ המיגרציה הקיים בפרויקט):

```text
20260820114504_4f306565-3d82-4123-a0d5-fdb6d7216636.sql
```

## בדיקה אחרי הרצה

אם הצליח תראה:

```text
Target project: gicsknanyctuxjfxvmqo
Running migration: <name> (<N> statements)
Migration completed successfully
```

## פתרון תקלות מהיר

1. `Refusing unexpected project: ...`
   `VITE_SUPABASE_PROJECT_ID`/`SUPABASE_PROJECT_ID` ב-`.env` לא שווה ל-`gicsknanyctuxjfxvmqo`.
   בדוק שלא הרצת את הכלי מתוך פרויקט אחר בטעות.
2. `Migration admin credentials are not configured`
   חסר `ADMIN_EMAIL`/`ADMIN_PASSWORD` (או `MIGRATION_ADMIN_EMAIL`/`MIGRATION_ADMIN_PASSWORD`).
3. `Admin login failed`
   האימייל/סיסמה שגויים, או שהחשבון לא קיים ב-Supabase Auth של הפרויקט הזה.
4. `Migration RPC returned failure` / שגיאת syntax
   יש שגיאת SQL בקובץ — בדוק את תוכן הקובץ ב-`supabase/migrations/`.
5. `Migration file must be inside supabase/migrations`
   הנתיב שהעברת לפקודת `file` חייב להיות בתוך תיקיית `supabase/migrations/` של הפרויקט.

## סיכום קצר

1. תמיד להריץ מה-root של הפרויקט (`C:\Users\jj121\synagogue-community`).
2. הפרויקט המורשה היחיד לכלי הזה הוא `gicsknanyctuxjfxvmqo` — מוגדר קשיח בקוד.
3. אין פקודת `sql` חופשית — כל מיגרציה חייבת להיות קובץ בתוך `supabase/migrations/`.
4. לפני הרצה בפרודקשן, לבדוק קודם בסביבת dev/staging אם קיימת כזו.
