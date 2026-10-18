# School Management System — System Structure

## Platform

- Front end: responsive HTML/CSS/JavaScript in `index.html`.
- Identity: Supabase Auth email/password.
- Authorization: `public.profiles.role`; never allow users to choose their own privileged role.
- Database: Supabase project `emdmnimxeoifgobzuglx`; preserve existing school, profile, student and marks data.
- Browser client uses only the public Supabase key. Never expose service-role keys.

## Roles and panels

1. **`developer`** — platform-wide, no school assignment; school approvals, suspensions/reactivation, user management, analytics, subscriptions, system health, audit logs, demo centre, support, platform settings, feature management, notifications, incidents, privacy requests, integrations, scheduled tasks and data quality.
2. **`administrator`** — one approved school; school settings, academic calendar, classes/streams, subjects, students, teachers and assignments, examinations, marks entry, attendance, grading scales, rubrics/competencies, fees, announcements and academic reports.
3. **`teacher`** — assigned classes, streams and subjects; marks entry and announcements. Teachers cannot manage school-wide class/student administration or choose the academic year/term.
4. **`bursar`** — fee charges, balances, payment recording, receipts, payment history and finance reports.
5. **`parent`** — linked children only; results, attendance, fee charges, payments and balances.
6. **`student`** — own profile, results, subjects, attendance and fee statement.

## Education-level rules

- **Pre-Primary:** PP1 and PP2.
- **Primary:** Grades 1–6.
- **Junior School:** Grades 7–9.
- **Senior School:** Grades 10–12 with pathways and tracks.

Only levels registered for a school appear in its grade options. Classes and streams are separate per grade. Subjects must match their education level and grade. Senior School subjects and new/edited student placements require a configured pathway and track. Marks and competency assessments must match the student’s grade and, for Senior School, pathway/track. Student and subject rankings reset within each grade and within each Senior School pathway/track cohort.

## Academic calendar and assessment workflow

- Administrator sets the school-wide active academic year and term in **School Settings**.
- Exams and payment records inherit the school-wide year and term.
- Teachers are assigned classes, streams and subjects by the administrator; new teacher registration requires at least two distinct subjects.
- Teachers can save marks for one student or part of a class, continue later, and submit marks. Missing marks are not treated as zero.
- School-specific grading ranges and competency rubrics are used in reports.
- Academic reports are administrator-only and include filters for education level, grade, stream, Senior School pathway/track, subject, gender, exam and analysis type. Rankings do not mix grades or Senior School pathways/tracks.
- Fee charges can be applied to all students in a selected class/stream. Student, parent, administrator and bursar views calculate totals from recorded charges and payments.

## CBE/CBC additions (additive)

- Curriculum & Learning Areas helps administrators review level-specific setup while preserving the school's existing classes, subjects, grading rules and rubrics.
- Learner portfolios capture project/practical/presentation/observation evidence and competency tags.
- Learning support plans track a specific learning need, support action, target/review date, status and outcome.
- Learning reflections record strengths and next steps.
- Assessment moderation logs preserve review status and notes.
- Core Competencies & Values tracks core competencies, values and PCIs with achievement evidence and next steps.
- Learner Accommodations stores staff-only instructional, assessment, accessibility and communication adjustments.
- Community Service Learning tracks school projects, partners, dates, outcomes and status; portfolio entries can store learner evidence.
- Additive migrations: `20261018000000_cbe_cbc_additions.sql`, `20261018003000_cbe_cbc_policy_tuning.sql`, and `20261018004000_cbe_competencies_inclusion_service_learning.sql`, and `20261018005000_cbe_cbc_fk_indexes.sql`. These add tables/policies/indexes without dropping existing tables or changing existing marks.
- Competency rubrics are separate from numerical grading ranges; never assume every competency level should be converted into a percentage.

## Data integrity and security

- RLS scopes school records to the signed-in user’s school and role.
- Database triggers validate registered education levels, class/stream membership, subject/teacher assignment, mark/subject/student consistency, fee amounts and same-school relationships.
- Unique indexes prevent duplicate class/stream pairs, student admission numbers, staff numbers and subject definitions.
- Removing a level already used by classes, subjects, students, grading scales or rubric criteria is blocked.
- Older Senior School student/subject records with missing pathway data are preserved and can be completed in the administrator’s placement/classification forms.
- Parent/student records depend on secure account links. Never expose service-role secrets in GitHub Pages.
- Email/WhatsApp buttons open drafts; they do not silently send messages.
- Backups are managed in Supabase project settings.

## Verification note

The JavaScript validator checks that inline code parses, and GitHub Pages builds the site. Both must pass, but production readiness also requires signing in with each role and testing database writes, RLS isolation, marks submission, fee balances and report outputs against real school data.
