-- Seller Pro — v0.22: 2 fontes independentes de Google Forms.
-- IMPORTANTE: executar SOMENTE no projeto de TESTES qpczaqrnxjncetotuhwl.
-- Mantém registros existentes e arquiva eventuais respostas antigas que ficaram pendentes.

alter table public.entradas_forms
  add column if not exists origem_tipo text not null default 'novo';
alter table public.entradas_forms
  add column if not exists resposta_em timestamptz;

-- A migração 009 originalmente só permitia pendente/processado.
alter table public.entradas_forms drop constraint if exists entradas_forms_status_check;
alter table public.entradas_forms
  add constraint entradas_forms_status_check
  check (status in ('pendente','processado','arquivado'));

-- Uma importação passada da planilha antiga deve sair da fila de novos.
update public.entradas_forms
  set origem_tipo = 'historico',
      status = case when status = 'pendente' then 'arquivado' else status end
  where origem_id like 'gsheet:1bQZRKsvnFfEjp4BRB4ZGX3nf1U8dTQvoZc9itxGb_Bo:%';

update public.entradas_forms
  set origem_tipo = 'novo'
  where origem_id like 'gsheet:1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ:%';

alter table public.entradas_forms drop constraint if exists entradas_forms_origem_tipo_check;
alter table public.entradas_forms
  add constraint entradas_forms_origem_tipo_check
  check (origem_tipo in ('historico','novo'));

create index if not exists entradas_forms_tipo_status_idx
  on public.entradas_forms(origem_tipo, status, recebido_em desc);

comment on column public.entradas_forms.origem_tipo is
  'historico = planilha anterior; novo = planilha atual. Classificado no servidor pelo ID da planilha.';
comment on column public.entradas_forms.resposta_em is
  'Momento original do envio no Google Forms, quando disponível; não é a data da importação.';

-- Diagnóstico sem expor dados pessoais
select origem_tipo, status, count(*) as quantidade
from public.entradas_forms group by origem_tipo, status order by origem_tipo, status;
