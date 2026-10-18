# School Management System

Mobile-friendly, multi-school management system built with HTML/CSS/JavaScript, Supabase Auth, PostgreSQL and row-level security.

- **Live app:** https://wwwsamuelsimiyu540-sketch.github.io/school-management-system-/
- **Main interface:** `index.html`
- **System roles and workflow:** `SYSTEM_STRUCTURE.md`
- **Teacher registration function:** `supabase/functions/school-register-teacher/index.ts`

## Role-based panels

- **Developer:** platform dashboard, school approval/suspension, users, system analytics, subscriptions, system health, audit logs, demo centre, support, settings and data-quality tools.
- **Administrator:** school settings, classes/streams, subjects, students, teachers and assignments, examinations, marks, attendance, grading rules, rubrics/competencies, fees, announcements and academic reports.
- **Teacher:** assigned classes/streams/subjects, marks entry, announcements and teaching performance charts.
- **Bursar:** fee charges by class/stream, student balances, payment recording, receipts, payment history and fee reports.
- **Parent:** linked children’s results, attendance, fee charges, payments and balances.
- **Student:** own profile, results, subjects, attendance, fee charges, payments and balance.

## School-level setup

The school registration and administrator settings control which education levels are available:

- **Pre-Primary:** PP1–PP2
- **Primary:** Grades 1–6
- **Junior School:** Grades 7–9
- **Senior School:** Grades 10–12, with pathways and tracks

The system filters grades, subjects, streams, teacher assignments and academic reporting to the school’s registered levels. Senior School students must be assigned a pathway and track that has subjects configured for their grade. Subject-specific marks and competency assessments are checked against the student’s grade and pathway/track. Academic rankings are grouped by grade, and by pathway/track for Senior School.

The administrator sets the school-wide academic year and term once in **School Settings**. Exams, marks and fee transactions inherit that calendar. Teachers do not choose their own academic year or term.

## CBE/CBC additions (additive)

- **Curriculum & Learning Areas** gives administrators a level-aware setup checklist and links to existing subject, grading and rubric configuration; subject lists must be checked against current KICD curriculum designs.
- **Learner Portfolio** records project/practical/presentation/observation evidence, optional evidence links, learning areas and competency tags without replacing exam marks.
- **Learning Support** records learner-specific needs, support actions, target/review dates and outcomes.
- **Learning Reflections** stores teacher observations, learner strengths and next steps.
- **Assessment Moderation** records administrator review status and notes.
- New tables are introduced in `supabase/migrations/20261018000000_cbe_cbc_additions.sql`; the migration is additive and does not drop or rewrite existing records. Apply it to the linked Supabase project before using the new panels.
- Competency rubrics remain separate from numeric grading scales; assessment evidence should not be automatically converted into a numeric mark unless the applicable assessment policy requires it.

## Data and security

- Supabase Auth determines the signed-in user. Users cannot grant themselves privileged roles from the login form.
- The browser uses only the public Supabase key. Never put a service-role key in frontend code.
- PostgreSQL triggers validate grade/level, class/stream, subject assignment, marks, fee charges and same-school relationships.
- Duplicate class/stream names, student admission numbers, staff numbers and subject definitions are blocked by normalized unique indexes.
- Removing an education level that already has school records is blocked so existing data is not silently hidden.
- Teacher registration is server-side and requires at least two distinct subjects.
- Student fee charges are recorded per student, school year and term; the system calculates billed, paid and outstanding totals.
- Existing records are preserved. Older Senior School records without pathway data can be completed in **Update student placement and pathway** and **Complete Senior School subject pathways**.

## Deploy and verify

GitHub Pages publishes the frontend; Supabase provides authentication, database and Edge Functions. Check the GitHub Actions status after each commit:

- JavaScript validation: https://github.com/wwwsamuelsimiyu540-sketch/school-management-system-/actions
- Repository: https://github.com/wwwsamuelsimiyu540-sketch/school-management-system-

JavaScript syntax and deployment checks do not replace live end-to-end tests. Before production use, test each role with real sign-ins and confirm forms save, access is restricted correctly, and reports match school data.

## Operational limitations

- Email and WhatsApp actions open drafts in the user’s installed apps; they do not send messages in the background.
- Database backups are managed through Supabase project backup settings, not by the public browser.
- Fee balances are based on the charges and payments recorded in the system; any external or historical balances must be entered before the totals can be complete.
