-- Seller Pro v0.5. Sem alterar registros existentes.
-- Atualizacao automatica do campo atualizado_em quando o chamado for editado.
-- Nota: respostas da Amazon so alterarao este campo quando existir integracao.
create or replace function public.set_chamado_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end; $$;

drop trigger if exists trg_chamados_atualizado_em on public.chamados;
create trigger trg_chamados_atualizado_em
before update on public.chamados
for each row execute function public.set_chamado_atualizado_em();

create index if not exists idx_chamados_atualizado_em on public.chamados(atualizado_em desc);
create index if not exists idx_sellers_nome on public.sellers(nome);
-- O relacionamento 1:N ja existe via chamados.seller_id -> sellers.id.
