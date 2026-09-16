-- Administrators read operational configuration through RLS; writes stay
-- inside the protected update function. Browser roles otherwise see nothing.

create policy configuration_admin_read on public.operational_configuration
for select to authenticated
using (public.is_admin());

grant select on table public.operational_configuration to authenticated;
