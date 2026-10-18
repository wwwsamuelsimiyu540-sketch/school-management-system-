-- Enforce school-level boundaries and senior-school pathways for new and edited records.
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS pathway text, ADD COLUMN IF NOT EXISTS track text;

CREATE OR REPLACE FUNCTION public.school_level_for_grade(p_grade text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
SELECT CASE
 WHEN trim(coalesce(p_grade,'')) IN ('PP1','PP2') THEN 'Pre-Primary'
 WHEN trim(coalesce(p_grade,'')) ~ '^Grade ([1-6])$' THEN 'Primary'
 WHEN trim(coalesce(p_grade,'')) ~ '^Grade ([7-9])$' THEN 'Junior School'
 WHEN trim(coalesce(p_grade,'')) ~ '^Grade (1[0-2])$' THEN 'Senior School'
 ELSE NULL END;
$$;
REVOKE EXECUTE ON FUNCTION public.school_level_for_grade(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.validate_school_level_record()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE g text; lev text; allowed text[]; student_pathway text; student_track text;
BEGIN
 IF TG_TABLE_NAME IN ('exam_marks','attendance_records','fee_payments') THEN
  SELECT grade,pathway,track INTO g,student_pathway,student_track FROM public.students WHERE id=NEW.student_id AND school_id=NEW.school_id;
  IF g IS NULL THEN RAISE EXCEPTION 'The selected student must belong to this school.' USING ERRCODE='23514'; END IF;
 ELSE
  g:=NEW.grade;
  IF TG_TABLE_NAME='students' THEN student_pathway:=NEW.pathway; student_track:=NEW.track; END IF;
 END IF;
 lev:=public.school_level_for_grade(g);
 IF lev IS NULL THEN RAISE EXCEPTION 'Invalid grade/class "%". Use PP1–PP2 or Grade 1–12.',g USING ERRCODE='23514'; END IF;
 SELECT school_level INTO allowed FROM public.schools WHERE id=NEW.school_id;
 IF allowed IS NULL OR NOT (lev=ANY(allowed)) THEN RAISE EXCEPTION 'This school has not registered the education level for %.',g USING ERRCODE='23514'; END IF;

 IF TG_TABLE_NAME='subjects' THEN
  IF NEW.education_level IS DISTINCT FROM lev THEN RAISE EXCEPTION 'Subject education level must match its grade.' USING ERRCODE='23514'; END IF;
  IF lev='Senior School' AND (nullif(trim(coalesce(NEW.pathway,'')),'') IS NULL OR nullif(trim(coalesce(NEW.track,'')),'') IS NULL) THEN RAISE EXCEPTION 'Senior School subjects must have a pathway and track.' USING ERRCODE='23514'; END IF;
  IF lev<>'Senior School' AND (nullif(trim(coalesce(NEW.pathway,'')),'') IS NOT NULL OR nullif(trim(coalesce(NEW.track,'')),'') IS NOT NULL) THEN RAISE EXCEPTION 'Pathways and tracks are only valid for Senior School subjects.' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='students' THEN
  IF NOT EXISTS(SELECT 1 FROM public.school_classes c WHERE c.school_id=NEW.school_id AND c.grade=NEW.grade AND c.stream=NEW.stream) THEN RAISE EXCEPTION 'Register the grade and stream before enrolling students.' USING ERRCODE='23514'; END IF;
  IF lev='Senior School' THEN
   IF nullif(trim(coalesce(NEW.pathway,'')),'') IS NULL OR nullif(trim(coalesce(NEW.track,'')),'') IS NULL THEN
    IF TG_OP='INSERT' OR NEW.grade IS DISTINCT FROM OLD.grade OR NEW.pathway IS DISTINCT FROM OLD.pathway OR NEW.track IS DISTINCT FROM OLD.track THEN RAISE EXCEPTION 'Senior School students must have a pathway and track.' USING ERRCODE='23514'; END IF;
   ELSIF NOT EXISTS(SELECT 1 FROM public.subjects s WHERE s.school_id=NEW.school_id AND s.grade=NEW.grade AND s.education_level='Senior School' AND s.pathway=NEW.pathway AND s.track=NEW.track) THEN
    RAISE EXCEPTION 'Choose a pathway and track with subjects configured for this grade.' USING ERRCODE='23514';
   END IF;
  ELSIF nullif(trim(coalesce(NEW.pathway,'')),'') IS NOT NULL OR nullif(trim(coalesce(NEW.track,'')),'') IS NOT NULL THEN RAISE EXCEPTION 'Pathways and tracks are only used for Senior School students.' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='teacher_assignments' THEN
  IF NOT EXISTS(SELECT 1 FROM public.school_classes c WHERE c.school_id=NEW.school_id AND c.grade=NEW.grade AND c.stream=NEW.stream) THEN RAISE EXCEPTION 'Teacher assignments must use a registered class and stream.' USING ERRCODE='23514'; END IF;
  IF NEW.subject_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.subjects s WHERE s.id=NEW.subject_id AND s.school_id=NEW.school_id AND s.grade=NEW.grade AND s.education_level=lev AND (lev<>'Senior School' OR (nullif(trim(coalesce(s.pathway,'')),'') IS NOT NULL AND nullif(trim(coalesce(s.track,'')),'') IS NOT NULL))) THEN RAISE EXCEPTION 'Assigned subject must match this school and grade; Senior School subjects need a pathway and track.' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=NEW.teacher_id AND p.school_id=NEW.school_id AND p.role='teacher') THEN RAISE EXCEPTION 'Select a teacher account belonging to this school.' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='school_grading_scales' THEN
  IF NEW.education_level IS DISTINCT FROM lev THEN RAISE EXCEPTION 'Grading scale education level must match its grade.' USING ERRCODE='23514'; END IF;
  IF NEW.min_score<0 OR NEW.max_score>100 OR NEW.min_score>NEW.max_score THEN RAISE EXCEPTION 'Grading ranges must be within 0–100 and minimum cannot exceed maximum.' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='school_rubric_criteria' THEN
  IF NEW.education_level IS NOT NULL AND NEW.education_level IS DISTINCT FROM lev THEN RAISE EXCEPTION 'Rubric education level must match its grade.' USING ERRCODE='23514'; END IF;
  IF NEW.subject_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.subjects s WHERE s.id=NEW.subject_id AND s.school_id=NEW.school_id AND s.grade=NEW.grade) THEN RAISE EXCEPTION 'Rubric subject must belong to the selected grade and school.' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='exam_marks' THEN
  IF NOT EXISTS(SELECT 1 FROM public.exams e JOIN public.subjects su ON su.id=NEW.subject_id AND su.school_id=NEW.school_id WHERE e.id=NEW.exam_id AND e.school_id=NEW.school_id AND su.grade=g AND (lev<>'Senior School' OR (su.pathway=student_pathway AND su.track=student_track))) THEN RAISE EXCEPTION 'Marks must match the student grade and pathway/track, subject and examination in the same school.' USING ERRCODE='23514'; END IF;
  IF NEW.marks<0 OR NEW.marks>100 THEN RAISE EXCEPTION 'Marks must be between 0 and 100.' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='fee_payments' THEN
  IF NEW.amount<=0 THEN RAISE EXCEPTION 'A fee payment must be greater than zero.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END; $$;
REVOKE EXECUTE ON FUNCTION public.validate_school_level_record() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS validate_school_classes_level ON public.school_classes;
CREATE TRIGGER validate_school_classes_level BEFORE INSERT OR UPDATE ON public.school_classes FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_students_school_level ON public.students;
CREATE TRIGGER validate_students_school_level BEFORE INSERT OR UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_subjects_school_level ON public.subjects;
CREATE TRIGGER validate_subjects_school_level BEFORE INSERT OR UPDATE ON public.subjects FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_teacher_assignments_school_level ON public.teacher_assignments;
CREATE TRIGGER validate_teacher_assignments_school_level BEFORE INSERT OR UPDATE ON public.teacher_assignments FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_school_grading_scales_level ON public.school_grading_scales;
CREATE TRIGGER validate_school_grading_scales_level BEFORE INSERT OR UPDATE ON public.school_grading_scales FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_school_rubric_criteria_level ON public.school_rubric_criteria;
CREATE TRIGGER validate_school_rubric_criteria_level BEFORE INSERT OR UPDATE ON public.school_rubric_criteria FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_exam_marks_school_grade ON public.exam_marks;
CREATE TRIGGER validate_exam_marks_school_grade BEFORE INSERT OR UPDATE ON public.exam_marks FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_attendance_school_student ON public.attendance_records;
CREATE TRIGGER validate_attendance_school_student BEFORE INSERT OR UPDATE ON public.attendance_records FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();
DROP TRIGGER IF EXISTS validate_fee_payment_school_student ON public.fee_payments;
CREATE TRIGGER validate_fee_payment_school_student BEFORE INSERT OR UPDATE ON public.fee_payments FOR EACH ROW EXECUTE FUNCTION public.validate_school_level_record();

CREATE OR REPLACE FUNCTION public.validate_school_rubric_assessment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE st public.students%ROWTYPE; su public.subjects%ROWTYPE; cr public.school_rubric_criteria%ROWTYPE;
BEGIN
 SELECT * INTO st FROM public.students WHERE id=NEW.student_id AND school_id=NEW.school_id;
 SELECT * INTO su FROM public.subjects WHERE id=NEW.subject_id AND school_id=NEW.school_id;
 SELECT * INTO cr FROM public.school_rubric_criteria WHERE id=NEW.criterion_id AND school_id=NEW.school_id;
 IF st.id IS NULL OR su.id IS NULL OR cr.id IS NULL THEN RAISE EXCEPTION 'Rubric student, subject and criterion must belong to the same school.' USING ERRCODE='23514'; END IF;
 IF st.grade<>su.grade OR cr.grade<>st.grade THEN RAISE EXCEPTION 'Rubric student, subject and criterion must match the same grade.' USING ERRCODE='23514'; END IF;
 IF public.school_level_for_grade(st.grade)='Senior School' AND (st.pathway IS DISTINCT FROM su.pathway OR st.track IS DISTINCT FROM su.track) THEN RAISE EXCEPTION 'Senior School rubric assessments must match the student pathway and track.' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.exams e WHERE e.id=NEW.exam_id AND e.school_id=NEW.school_id) THEN RAISE EXCEPTION 'Rubric examination must belong to the same school.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END; $$;
REVOKE EXECUTE ON FUNCTION public.validate_school_rubric_assessment() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS validate_school_rubric_assessment ON public.school_rubric_assessments;
CREATE TRIGGER validate_school_rubric_assessment BEFORE INSERT OR UPDATE ON public.school_rubric_assessments FOR EACH ROW EXECUTE FUNCTION public.validate_school_rubric_assessment();

CREATE OR REPLACE FUNCTION public.prevent_removing_school_levels_in_use()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.students s WHERE s.school_id=OLD.id AND public.school_level_for_grade(s.grade)=ANY(OLD.school_level) AND NOT (public.school_level_for_grade(s.grade)=ANY(NEW.school_level)))
 OR EXISTS(SELECT 1 FROM public.school_classes c WHERE c.school_id=OLD.id AND public.school_level_for_grade(c.grade)=ANY(OLD.school_level) AND NOT (public.school_level_for_grade(c.grade)=ANY(NEW.school_level)))
 OR EXISTS(SELECT 1 FROM public.subjects s WHERE s.school_id=OLD.id AND s.education_level=ANY(OLD.school_level) AND NOT (s.education_level=ANY(NEW.school_level)))
 OR EXISTS(SELECT 1 FROM public.school_grading_scales g WHERE g.school_id=OLD.id AND g.education_level=ANY(OLD.school_level) AND NOT (g.education_level=ANY(NEW.school_level)))
 OR EXISTS(SELECT 1 FROM public.school_rubric_criteria r WHERE r.school_id=OLD.id AND r.education_level=ANY(OLD.school_level) AND NOT (r.education_level=ANY(NEW.school_level))) THEN
  RAISE EXCEPTION 'Cannot remove an education level that already has classes, subjects, students, grading rules or rubric criteria.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END; $$;
REVOKE EXECUTE ON FUNCTION public.prevent_removing_school_levels_in_use() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS prevent_removing_school_levels_in_use ON public.schools;
CREATE TRIGGER prevent_removing_school_levels_in_use BEFORE UPDATE OF school_level ON public.schools FOR EACH ROW EXECUTE FUNCTION public.prevent_removing_school_levels_in_use();

CREATE UNIQUE INDEX IF NOT EXISTS school_classes_school_grade_stream_unique ON public.school_classes(school_id,grade,stream);
CREATE UNIQUE INDEX IF NOT EXISTS students_school_admission_unique ON public.students(school_id,lower(admission_no));
CREATE UNIQUE INDEX IF NOT EXISTS profiles_school_staff_no_unique ON public.profiles(school_id,lower(staff_no)) WHERE staff_no IS NOT NULL AND trim(staff_no)<>'';
CREATE UNIQUE INDEX IF NOT EXISTS subjects_school_level_grade_name_pathway_track_unique ON public.subjects(school_id,education_level,grade,lower(name),coalesce(pathway,''),coalesce(track,''));
