-- MIGRACAO OPCIONAL v0.7: resumo editavel em campo proprio.
-- Executar APENAS no Supabase de TESTES depois de backup.
-- O frontend funciona sem a coluna, usando a descricao original como resumo.
alter table public.chamados add column if not exists resumo text;
