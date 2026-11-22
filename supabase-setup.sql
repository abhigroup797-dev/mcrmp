-- Moulding Stock & Costing: database setup for Supabase.
-- Run this once: Supabase > SQL Editor > New query > paste everything > Run.
-- It is safe to run again.
--
-- It uses the same Supabase project and the same logins as Mould CRM, so the
-- Mould CRM setup (supabase-setup.sql in the mould-crm repository) must already
-- have been run in this project. Nothing that belongs to Mould CRM is changed.

do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception 'Table public.profiles is missing. Run the Mould CRM supabase-setup.sql in this project first, then run this file again.';
  end if;
end
$$;

-- ---------- who may use Stock & Costing ----------
-- Only the admin, to start with. Costs and margins are in here.
create or replace function public.mfg_can_use() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false)
$$;

-- ---------- data (stock items, part costing sheets, transactions) ----------
create table if not exists public.mfg_docs (
  id text primary key,
  coll text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.mfg_docs drop constraint if exists mfg_docs_coll_check;
alter table public.mfg_docs add constraint mfg_docs_coll_check
  check (coll in ('items', 'parts', 'txns'));
create index if not exists mfg_docs_coll_idx on public.mfg_docs (coll, id);
alter table public.mfg_docs enable row level security;

create or replace function public.mfg_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end
$$;
drop trigger if exists mfg_docs_touch on public.mfg_docs;
create trigger mfg_docs_touch before update on public.mfg_docs
  for each row execute function public.mfg_touch();

drop policy if exists "mfg read" on public.mfg_docs;
create policy "mfg read" on public.mfg_docs for select to authenticated
  using (public.mfg_can_use());

drop policy if exists "mfg add" on public.mfg_docs;
create policy "mfg add" on public.mfg_docs for insert to authenticated
  with check (public.mfg_can_use());

drop policy if exists "mfg change" on public.mfg_docs;
create policy "mfg change" on public.mfg_docs for update to authenticated
  using (public.mfg_can_use()) with check (public.mfg_can_use());

drop policy if exists "mfg delete" on public.mfg_docs;
create policy "mfg delete" on public.mfg_docs for delete to authenticated
  using (public.mfg_can_use());

-- Merges a change into one row (an item's name, cost or reorder level).
-- Stock quantity is never changed this way; only the two functions below change it.
create or replace function public.mfg_merge(p_id text, p_patch jsonb) returns void
language sql security invoker set search_path = public as $$
  update public.mfg_docs
     set data = data || (p_patch - 'qty')
   where id = p_id
$$;

-- Records one or more transactions and moves the stock in the same step, so a
-- transaction can never be saved without its stock change (or the other way round).
-- p_txns is a list of {"id": text, "data": {...}, "avg": true|false}.
-- With "avg": true a receipt also moves the item's cost to the weighted average.
create or replace function public.mfg_post(p_txns jsonb) returns void
language plpgsql security invoker set search_path = public as $$
declare
  t jsonb;
  d jsonb;
  v_item text;
  v_qty numeric;
  v_rate numeric;
  cur_qty numeric;
  cur_rate numeric;
  new_rate numeric;
begin
  if not public.mfg_can_use() then
    raise exception 'This login cannot change stock';
  end if;
  for t in select value from jsonb_array_elements(p_txns) loop
    d := t -> 'data';
    insert into public.mfg_docs (id, coll, data) values (t ->> 'id', 'txns', d);
    v_item := d ->> 'itemId';
    v_qty := coalesce((d ->> 'qty')::numeric, 0);
    if v_item is not null and v_item <> '' then
      select coalesce((data ->> 'qty')::numeric, 0), coalesce((data ->> 'rate')::numeric, 0)
        into cur_qty, cur_rate
        from public.mfg_docs
       where id = v_item and coll = 'items'
         for update;
      if found then
        new_rate := cur_rate;
        if coalesce((t ->> 'avg')::boolean, false) and v_qty > 0 then
          v_rate := coalesce((d ->> 'rate')::numeric, 0);
          new_rate := round((greatest(cur_qty, 0) * cur_rate + v_qty * v_rate) / (greatest(cur_qty, 0) + v_qty), 4);
        end if;
        update public.mfg_docs
           set data = data || jsonb_build_object('qty', round(cur_qty + v_qty, 3), 'rate', new_rate)
         where id = v_item;
      end if;
    end if;
  end loop;
end
$$;

-- Deletes a transaction and takes its stock change back in the same step.
create or replace function public.mfg_delete_txn(p_id text) returns void
language plpgsql security invoker set search_path = public as $$
declare
  d jsonb;
  v_item text;
  v_qty numeric;
begin
  if not public.mfg_can_use() then
    raise exception 'This login cannot change stock';
  end if;
  delete from public.mfg_docs where id = p_id and coll = 'txns' returning data into d;
  if not found then
    return;
  end if;
  v_item := d ->> 'itemId';
  v_qty := coalesce((d ->> 'qty')::numeric, 0);
  if v_item is not null and v_item <> '' and v_qty <> 0 then
    update public.mfg_docs
       set data = data || jsonb_build_object('qty', round(coalesce((data ->> 'qty')::numeric, 0) - v_qty, 3))
     where id = v_item and coll = 'items';
  end if;
end
$$;

-- ---------- permissions for the website ----------
revoke all on public.mfg_docs from anon;
revoke execute on function public.mfg_merge(text, jsonb), public.mfg_post(jsonb), public.mfg_delete_txn(text) from public, anon;
grant select, insert, update, delete on public.mfg_docs to authenticated;
grant execute on function public.mfg_can_use() to authenticated;
grant execute on function public.mfg_merge(text, jsonb), public.mfg_post(jsonb), public.mfg_delete_txn(text) to authenticated;

-- ---------- live updates ----------
do $$
begin
  alter publication supabase_realtime add table public.mfg_docs;
exception when others then null;
end
$$;

-- Tell the API about the new table and functions straight away.
notify pgrst, 'reload schema';
