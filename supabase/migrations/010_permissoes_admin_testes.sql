-- Executar somente no projeto Supabase de TESTES.
-- A função gerenciar-funcionarios usa service_role no servidor.
GRANT USAGE ON SCHEMA public TO service_role;
GRANT SELECT, UPDATE (precisa_trocar_senha)
ON TABLE public.usuarios TO service_role;
-- Não modifica as permissões de anon ou authenticated.
SELECT
  has_table_privilege('service_role','public.usuarios','SELECT') AS pode_listar,
  has_column_privilege('service_role','public.usuarios','precisa_trocar_senha','UPDATE') AS pode_resetar_flag;
