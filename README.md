# My School System Manager

A mobile-friendly school management system with role-based panels and Supabase Auth/database integration.

## Start here
- `index.html` — login, dashboards and school modules.
- `super_admin-portal.html` — shortcut to the Super Admin Panel.
- `school-approvals.html` — Super Admin school registration, request approvals, and activation/suspension controls.
- `SYSTEM_STRUCTURE.md` — agreed system roles, panels and modules.
- `supabase/migrations/20261011160000_school_management_core_modules.sql` — core school modules and row-level security policies.
- `supabase/migrations/20261011190000_school_registration_requests.sql` — school registration requests and approval access policies.
- `supabase/migrations/20261012100000_super_admin_role_school_lifecycle.sql` — Super Admin role and school lifecycle fields/policies.

## Roles
- `super_admin`: platform-wide school registration, approvals, activation/suspension, monitoring; the Super Admin profile must have `school_id = NULL`.
- `principal`: manages one assigned school, including teachers, students and academic records.
- `teacher`: attendance and examinations.
- `bursar`: fees and payments.
- `parent`: linked children's information.
- `student`: personal school information.

## Secure school and administrator creation
The Super Admin Panel calls the Supabase Edge Function `developer-register-school`. It creates an Auth account and school on the server, then assigns the new account the `principal` role and the new school's ID. The service-role key must remain a Supabase server secret and must never be put into browser code.

Before using the registration form:
1. Apply the SQL migrations in `supabase/migrations/` to the configured Supabase project.
2. Deploy the function: `supabase functions deploy developer-register-school`.
3. Ensure the Supabase Edge Function has its standard `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` secrets.
4. Verify the project profile schema supports `full_name`; adjust the function's profile upsert if your schema uses different column names.
5. Test using a Super Admin account whose `school_id` is null.

The browser only contains the public publishable key. Never expose the service-role key in GitHub Pages or frontend code.

## Important scope note
The Super Admin can register schools and administrators, review pending requests, and suspend/reactivate schools. The main Marks Entry interface is connected to Supabase: it filters by academic year, grade, stream, subject, term and examination; searches by student name/admission number; saves one student or all visible students; and publishes saved marks through the `published` fields. The database calculates `total_percentage` from CAT and exam marks, so frontend writes must not set that generated column. Other student/teacher CRUD areas still need end-to-end role-based testing before production use. Email/WhatsApp communication actions open drafts rather than sending automatically.
