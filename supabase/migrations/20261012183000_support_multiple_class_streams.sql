-- Allow each grade to have any number of streams (A, B, C, D, etc.).
-- Stream is a label, not a fixed two-stream enum; schools can use any naming scheme.
alter table public.school_classes
  add column if not exists stream text;

alter table public.students
  add column if not exists stream text;

create index if not exists school_classes_school_grade_stream_idx
  on public.school_classes (school_id, grade_level, stream);

create index if not exists students_school_grade_stream_idx
  on public.students (school_id, grade_level, stream);
