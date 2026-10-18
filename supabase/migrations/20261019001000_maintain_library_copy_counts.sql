-- Keep library availability counts atomic and consistent under concurrent loans/returns.
create or replace function public.maintain_library_available_copies()
returns trigger language plpgsql set search_path = '' as $$
declare available_now integer;
begin
 if tg_op='INSERT' then
  select available_copies into available_now from public.school_library_books
   where id=new.book_id and school_id=new.school_id for update;
  if not found then raise exception 'Library book not found in this school.'; end if;
  if available_now<1 then raise exception 'No available copies remain for this book.'; end if;
  update public.school_library_books set available_copies=available_copies-1,updated_at=now()
   where id=new.book_id and school_id=new.school_id;
  return new;
 elsif tg_op='UPDATE' and old.returned_at is null and new.returned_at is not null then
  update public.school_library_books set available_copies=least(total_copies,available_copies+1),updated_at=now()
   where id=new.book_id and school_id=new.school_id;
  return new;
 end if;
 return new;
end; $$;
drop trigger if exists school_library_loan_copy_count on public.school_library_loans;
create trigger school_library_loan_copy_count after insert or update of returned_at on public.school_library_loans
for each row execute function public.maintain_library_available_copies();