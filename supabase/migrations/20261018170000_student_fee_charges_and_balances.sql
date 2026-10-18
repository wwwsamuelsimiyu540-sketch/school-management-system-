ALTER TABLE public.fee_payments ADD COLUMN IF NOT EXISTS academic_year integer, ADD COLUMN IF NOT EXISTS term text;

CREATE TABLE IF NOT EXISTS public.student_fee_charges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
 student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
 description text NOT NULL CHECK(length(trim(description))>0),
 academic_year integer NOT NULL CHECK(academic_year BETWEEN 2000 AND 2100),
 term text NOT NULL CHECK(term IN ('Term 1','Term 2','Term 3','Semester 1','Semester 2')),
 amount numeric(12,2) NOT NULL CHECK(amount>0),
 due_date date,
 created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS student_fee_charges_unique_term ON public.student_fee_charges(school_id,student_id,lower(trim(description)),academic_year,term);
CREATE INDEX IF NOT EXISTS student_fee_charges_student_term_idx ON public.student_fee_charges(school_id,student_id,academic_year,term);
ALTER TABLE public.student_fee_charges ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.student_fee_charges TO authenticated;
GRANT ALL ON public.student_fee_charges TO service_role;

DROP POLICY IF EXISTS "fee charges read authorized" ON public.student_fee_charges;
CREATE POLICY "fee charges read authorized" ON public.student_fee_charges FOR SELECT TO authenticated USING (
 public.is_platform_developer()
 OR (school_id=(SELECT p.school_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
     AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role IN ('administrator','bursar')))
 OR EXISTS(SELECT 1 FROM public.student_account_links l WHERE l.student_id=student_fee_charges.student_id AND l.user_id=(SELECT auth.uid()) AND l.active=true AND l.school_id=student_fee_charges.school_id)
);
DROP POLICY IF EXISTS "fee charges insert authorized" ON public.student_fee_charges;
CREATE POLICY "fee charges insert authorized" ON public.student_fee_charges FOR INSERT TO authenticated WITH CHECK (
 public.is_platform_developer()
 OR (school_id=(SELECT p.school_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
     AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role IN ('administrator','bursar'))
     AND EXISTS(SELECT 1 FROM public.students s WHERE s.id=student_fee_charges.student_id AND s.school_id=student_fee_charges.school_id))
);
DROP POLICY IF EXISTS "fee charges update authorized" ON public.student_fee_charges;
CREATE POLICY "fee charges update authorized" ON public.student_fee_charges FOR UPDATE TO authenticated USING (
 public.is_platform_developer()
 OR (school_id=(SELECT p.school_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role IN ('administrator','bursar')))
) WITH CHECK (
 public.is_platform_developer()
 OR (school_id=(SELECT p.school_id FROM public.profiles p WHERE p.id=(SELECT auth.uid()))
     AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role IN ('administrator','bursar'))
     AND EXISTS(SELECT 1 FROM public.students s WHERE s.id=student_fee_charges.student_id AND s.school_id=student_fee_charges.school_id))
);
DROP POLICY IF EXISTS "fee charges delete authorized" ON public.student_fee_charges;
CREATE POLICY "fee charges delete authorized" ON public.student_fee_charges FOR DELETE TO authenticated USING (
 public.is_platform_developer()
 OR (school_id=(SELECT p.school_id FROM public.profiles p WHERE p.id=(SELECT auth.uid())) AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='administrator'))
);

CREATE OR REPLACE FUNCTION public.validate_student_fee_charge()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.amount<=0 OR NEW.academic_year<2000 OR NEW.academic_year>2100 OR length(trim(NEW.description))=0 THEN
  RAISE EXCEPTION 'Enter a valid fee description, academic year and positive amount.' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.students s WHERE s.id=NEW.student_id AND s.school_id=NEW.school_id) THEN
  RAISE EXCEPTION 'Fee charges must belong to a student in the same school.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END; $$;
REVOKE EXECUTE ON FUNCTION public.validate_student_fee_charge() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS validate_student_fee_charge ON public.student_fee_charges;
CREATE TRIGGER validate_student_fee_charge BEFORE INSERT OR UPDATE ON public.student_fee_charges FOR EACH ROW EXECUTE FUNCTION public.validate_student_fee_charge();
