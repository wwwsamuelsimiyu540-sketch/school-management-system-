drop policy if exists "assets_school_scope" on public.school_assets;
create policy "assets_bursar_only" on public.school_assets
for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assets.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_assets.school_id and p.role='bursar'));

drop policy if exists "inventory_admin_write" on public.school_inventory_items;
drop policy if exists "inventory_read_school" on public.school_inventory_items;
create policy "inventory_bursar_only" on public.school_inventory_items
for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_items.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_items.school_id and p.role='bursar'));

drop policy if exists "inventory_tx_read_school" on public.school_inventory_transactions;
drop policy if exists "inventory_tx_write_school" on public.school_inventory_transactions;
create policy "inventory_transactions_bursar_only" on public.school_inventory_transactions
for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_transactions.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_inventory_transactions.school_id and p.role='bursar'));

drop policy if exists "transport_admin_write" on public.school_transport_routes;
drop policy if exists "transport_read_school" on public.school_transport_routes;
create policy "transport_routes_bursar_only" on public.school_transport_routes
for all to authenticated
using ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_transport_routes.school_id and p.role='bursar'))
with check ((select is_platform_developer()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.school_id=school_transport_routes.school_id and p.role='bursar'));
