-- Cover foreign-key lookups for the additive CBE/CBC tables.
create index if not exists school_competency_observations_student_id_idx on public.school_competency_observations(student_id);
create index if not exists school_competency_observations_recorded_by_idx on public.school_competency_observations(recorded_by);
create index if not exists school_learner_accommodations_student_id_idx on public.school_learner_accommodations(student_id);
create index if not exists school_learner_accommodations_created_by_idx on public.school_learner_accommodations(created_by);
create index if not exists school_service_learning_projects_created_by_idx on public.school_service_learning_projects(created_by);
