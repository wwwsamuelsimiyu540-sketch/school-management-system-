# Friends Day Senior School Lukhome — System Structure

## Platform
- Front end: responsive HTML/CSS/JavaScript in `index.html`.
- Identity: Supabase Auth email/password.
- Authorization: role assigned in `public.profiles.role`; never allow the user to choose their role at login.
- Database: existing Supabase project `emdmnimxeoifgobzuglx`; keep the current school and profile records.
- Public client uses the Supabase publishable key only. Never put a service-role/secret key in browser code.

## Roles and panels
1. `developer` — platform-wide role with no school assignment (`school_id IS NULL`); reviews school registrations, activates/suspends schools, and manages platform users, activity, communications, reports and settings.
2. `principal` — school dashboard, students, teachers, classes, attendance, fees overview, exams/marks, report cards, announcements, calendar and school settings.
3. `teacher` — assigned classes, attendance, assessments/marks, class reports, announcements and calendar.
4. `bursar` — fee records, payments, balances, receipts and finance reports.
5. `parent` — linked children only; results, attendance, announcements and fee balances.
6. `student` — own results, attendance, timetable and announcements.

## Database modules
- Existing tables retained: `schools`, `profiles`, `students`, `exam_marks`, `platform_activity_log`, `platform_user_presence`, `platform_messages`.
- Added by the core migration: `teachers`, `school_classes`, `attendance_records`, `fee_payments`, `school_events`, `school_announcements`, `parent_student_links`, `school_messages`.
- School registration workflow: `school_registration_requests` (created and secured by `20261011190000_school_registration_requests.sql`).
- Row-level security is enabled on all new tables. Policies scope data to a school and reserve fee management for principal/bursar and platform oversight for developers.

## Important rollout notes
- Existing login and school/profile rows must be preserved.
- The browser may use only the publishable key; do not expose service-role keys.
- Production parent/student isolation depends on linking accounts correctly in `parent_student_links` and on appropriate RLS policies for the existing student/marks tables.
- WhatsApp/email actions open the user's installed app or email client; they do not send messages in the background.
- Counts and activity panels should be labeled accurately when a table has no records yet.


## School lifecycle and marks workflow
- School registration requests start as `pending`; Developer can approve or reject them.
- Approval creates a school and assigns the requesting principal to that school. Rejection does not grant school access.
- Developer can set an approved school's status to `suspended` and later restore it to `approved`.
- School administrators register teachers and students within their own workspace. The marks screen supports searching by student name, class, or admission number before entering marks.
- The Academic Suite's student/teacher/marks records are currently a browser-local prototype; connect these write paths to Supabase and enforce RLS before production use.
