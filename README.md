# Friends Day Senior School Lukhome — School Management System

A mobile-friendly school management system with role-based panels and Supabase Auth/database integration.

## Start here
- `index.html` — login, dashboards and live school modules.
- `SYSTEM_STRUCTURE.md` — agreed system roles, panels and modules.
- `supabase/migrations/20261011160000_school_management_core_modules.sql` — database additions and row-level security policies.

## Roles
- `super_admin`: platform overview, schools, users/roles, activity monitor, communications and reports.
- `principal`: school operations and school settings.
- `teacher`: attendance and examinations.
- `bursar`: fees and payments.
- `parent`: linked children’s information.
- `student`: personal school information.

## Supabase
The front end uses the existing Supabase project and a public publishable key. Never add a service-role key to browser code. Authentication is handled by Supabase Auth, and the assigned role is read from `public.profiles.role`.

The migration keeps existing tables and data and adds teachers, classes, attendance, fee payments, events, announcements, parent/student links and school messages. Row-level security is enabled on the new tables.

## Notes
- Real data modules require a signed-in Supabase account with a profile and school assignment.
- The communication centre records messages. Email and WhatsApp open a pre-filled draft in the user's app; the site does not send messages automatically.
- Configure and verify parent/student account links before using those portals with real student records.
- The application is a static HTML site; publish `index.html` with GitHub Pages or your existing static host.
