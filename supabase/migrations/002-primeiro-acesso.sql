-- EXECUTAR UMA VEZ NO SQL EDITOR (PROJETO SELLER PRO)
-- Permite atualizar a flag somente pelo backend administrativo.
GRANT UPDATE (precisa_trocar_senha) ON public.usuarios TO service_role;

-- Usuários em primeiro acesso não podem acessar dados dos chamados.
-- Mantemos a leitura do próprio perfil via policy separada.
CREATE OR REPLACE FUNCTION private.usuario_ativo()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
 SELECT EXISTS (
   SELECT 1 FROM public.usuarios
   WHERE id = (SELECT auth.uid())
     AND ativo IS TRUE
     AND precisa_trocar_senha IS FALSE
 );
$$;

REVOKE ALL ON FUNCTION private.usuario_ativo() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.usuario_ativo() TO authenticated;

-- Confirmar se o papel de backend possui UPDATE da coluna.
SELECT has_column_privilege('service_role','public.usuarios','precisa_trocar_senha','UPDATE') AS pode_atualizar_flag;
