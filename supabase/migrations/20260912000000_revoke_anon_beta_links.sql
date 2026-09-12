-- Restore the guest beta-link privacy boundary after the gym summary grant.
-- The count-only SECURITY DEFINER RPC remains the public beta surface.
revoke all privileges on table public.beta_links from anon;

-- A column-level grant is independent of a table-level grant in PostgreSQL.
-- Remove any such grants as well, including columns added in future schema
-- migrations without requiring this repair to enumerate sensitive metadata.
do $$
declare
  beta_column text;
begin
  for beta_column in
    select attribute.attname
    from pg_catalog.pg_attribute as attribute
    where attribute.attrelid = 'public.beta_links'::pg_catalog.regclass
      and attribute.attnum > 0
      and not attribute.attisdropped
  loop
    execute format(
      'revoke select (%I) on table public.beta_links from anon',
      beta_column
    );
  end loop;
end;
$$;
