-- EXECUTAR SOMENTE NO PROJETO DE TESTES qpczaqrnxjncetotuhwl
-- Fila isolada: sem criação automática de pessoas, lojas ou tickets.
create table if not exists public.entradas_forms (
 id uuid primary key default gen_random_uuid(),
 origem_id text not null unique,
 recebido_em timestamptz not null default now(),
 nome text,
 mcid text,
 resumo text,
 respostas jsonb not null default '{}'::jsonb,
 status text not null default 'pendente' check (status in ('pendente','processado')),
 chamado_id uuid references public.chamados(id),
 processado_em timestamptz
);
create index if not exists entradas_forms_status_recebido_idx on public.entradas_forms(status,recebido_em desc);
alter table public.entradas_forms enable row level security;
revoke all on public.entradas_forms from anon,authenticated;
grant select on public.entradas_forms to authenticated;
grant update (status, chamado_id, processado_em) on public.entradas_forms to authenticated;
grant select,insert,update on public.entradas_forms to service_role;
drop policy if exists entradas_forms_ler on public.entradas_forms;
create policy entradas_forms_ler on public.entradas_forms for select to authenticated
 using (exists (select 1 from public.usuarios u where u.id=auth.uid() and u.ativo=true and coalesce(u.precisa_trocar_senha,false)=false));
drop policy if exists entradas_forms_atualizar on public.entradas_forms;
create policy entradas_forms_atualizar on public.entradas_forms for update to authenticated
 using (exists (select 1 from public.usuarios u where u.id=auth.uid() and u.ativo=true and coalesce(u.precisa_trocar_senha,false)=false))
 with check (exists (select 1 from public.usuarios u where u.id=auth.uid() and u.ativo=true and coalesce(u.precisa_trocar_senha,false)=false));
-- Validação
select table_name from information_schema.tables where table_schema='public' and table_name='entradas_forms';
