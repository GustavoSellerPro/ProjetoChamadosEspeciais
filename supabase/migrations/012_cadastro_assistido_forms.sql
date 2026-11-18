-- Seller Pro v0.23: Cadastro assistido pela conferência de Forms.
-- Executar SOMENTE no projeto Supabase de TESTES qpczaqrnxjncetotuhwl.
-- Pré-requisitos: estrutura v0.7 + migrações 009 e 011.
-- Não cria casos nem tickets; nunca usa "XXX" como MCID real.
BEGIN;

ALTER TABLE public.entradas_forms
  ADD COLUMN IF NOT EXISTS seller_id uuid REFERENCES public.sellers(id) ON DELETE RESTRICT;
ALTER TABLE public.entradas_forms
  ADD COLUMN IF NOT EXISTS loja_id uuid REFERENCES public.lojas_amazon(id) ON DELETE RESTRICT;
ALTER TABLE public.lojas_amazon
  ADD COLUMN IF NOT EXISTS situacao_conta text;

ALTER TABLE public.lojas_amazon
  DROP CONSTRAINT IF EXISTS lojas_amazon_situacao_conta_check;
ALTER TABLE public.lojas_amazon
  ADD CONSTRAINT lojas_amazon_situacao_conta_check
  CHECK (situacao_conta IS NULL OR situacao_conta IN
    ('Conta não criada', 'Criação em andamento', 'Criação bloqueada', 'Conta ativa'));

CREATE INDEX IF NOT EXISTS entradas_forms_seller_id_idx ON public.entradas_forms(seller_id);
CREATE INDEX IF NOT EXISTS entradas_forms_loja_id_idx ON public.entradas_forms(loja_id);
GRANT UPDATE (seller_id, loja_id) ON public.entradas_forms TO authenticated;

-- Uma chamada RPC = 1 transação: sem vendedor órfão se falhar ao vincular ao Forms.
CREATE OR REPLACE FUNCTION public.forms_confirmar_seller(
  p_entrada_id uuid,
  p_nome text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_telefone text DEFAULT NULL,
  p_seller_existente_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_form public.entradas_forms%ROWTYPE;
  v_id uuid;
  v_nome text;
  v_email text;
  v_telefone text;
  v_criado boolean := false;
BEGIN
  IF (SELECT private.usuario_ativo()) IS NOT TRUE THEN
    RAISE EXCEPTION 'Usuário não autorizado';
  END IF;
  SELECT * INTO v_form FROM public.entradas_forms
    WHERE id = p_entrada_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Formulário não encontrado'; END IF;
  IF v_form.origem_tipo <> 'novo' OR v_form.status <> 'pendente' THEN
    RAISE EXCEPTION 'Somente formulários novos e pendentes podem gerar cadastros';
  END IF;
  IF v_form.seller_id IS NOT NULL THEN
    RETURN pg_catalog.jsonb_build_object('seller_id',v_form.seller_id,'criado',false,'ja_vinculado',true);
  END IF;

  IF p_seller_existente_id IS NOT NULL THEN
    SELECT id INTO v_id FROM public.sellers WHERE id = p_seller_existente_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Pessoa selecionada não existe ou não está acessível'; END IF;
  ELSE
    v_nome := pg_catalog.btrim(COALESCE(p_nome,''));
    v_email := NULLIF(pg_catalog.lower(pg_catalog.btrim(COALESCE(p_email,''))), '');
    v_telefone := NULLIF(pg_catalog.btrim(COALESCE(p_telefone,'')), '');
    IF pg_catalog.length(v_nome) < 3 THEN RAISE EXCEPTION 'Informe o nome completo da pessoa'; END IF;
    -- Impede que dois formulários concorrentes criem o mesmo seller por e-mail/telefone.
    IF v_email IS NOT NULL THEN
      PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sellerpro-forms-pessoa-email:' || v_email, 0));
    END IF;
    IF v_telefone IS NOT NULL AND pg_catalog.length(pg_catalog.regexp_replace(v_telefone,'[^0-9]','','g')) >= 10 THEN
      PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
        'sellerpro-forms-pessoa-telefone:' || pg_catalog.regexp_replace(v_telefone,'[^0-9]','','g'), 0));
    END IF;
    IF v_email IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.sellers s
      WHERE s.email IS NOT NULL AND pg_catalog.lower(pg_catalog.btrim(s.email)) = v_email
    ) THEN
      RAISE EXCEPTION 'Este e-mail já aparece em uma pessoa. Selecione o cadastro existente.';
    END IF;
    IF v_telefone IS NOT NULL AND pg_catalog.length(pg_catalog.regexp_replace(v_telefone,'[^0-9]','','g')) >= 10
      AND EXISTS (
        SELECT 1 FROM public.sellers s
        WHERE pg_catalog.regexp_replace(COALESCE(s.telefone,''),'[^0-9]','','g') = pg_catalog.regexp_replace(v_telefone,'[^0-9]','','g')
      ) THEN
      RAISE EXCEPTION 'Este telefone já aparece em uma pessoa. Verifique e vincule o cadastro existente.';
    END IF;
    INSERT INTO public.sellers(nome,email,telefone)
      VALUES (v_nome,v_email,v_telefone)
      RETURNING id INTO v_id;
    v_criado := true;
  END IF;

  UPDATE public.entradas_forms SET seller_id = v_id WHERE id = p_entrada_id;
  RETURN pg_catalog.jsonb_build_object('seller_id',v_id,'criado',v_criado,'ja_vinculado',false);
END;
$$;

CREATE OR REPLACE FUNCTION public.forms_vincular_loja(
  p_entrada_id uuid,
  p_mcid text DEFAULT NULL,
  p_cnpj text DEFAULT NULL,
  p_nome_loja text DEFAULT NULL,
  p_email_conta text DEFAULT NULL,
  p_situacao_conta text DEFAULT NULL,
  p_loja_existente_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_form public.entradas_forms%ROWTYPE;
  v_id uuid;
  v_owner uuid;
  v_mcid text;
  v_cnpj text;
  v_situacao text;
  v_count integer;
  v_existing_mcid text;
  v_existing_cnpj text;
  v_criado boolean := false;
BEGIN
  IF (SELECT private.usuario_ativo()) IS NOT TRUE THEN
    RAISE EXCEPTION 'Usuário não autorizado';
  END IF;
  SELECT * INTO v_form FROM public.entradas_forms WHERE id = p_entrada_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Formulário não encontrado'; END IF;
  IF v_form.origem_tipo <> 'novo' OR v_form.status <> 'pendente' THEN
    RAISE EXCEPTION 'Somente formulários novos e pendentes podem gerar cadastros';
  END IF;
  IF v_form.seller_id IS NULL THEN RAISE EXCEPTION 'Crie ou vincule a pessoa primeiro'; END IF;
  IF v_form.loja_id IS NOT NULL THEN
    RETURN pg_catalog.jsonb_build_object('loja_id',v_form.loja_id,'criado',false,'ja_vinculado',true);
  END IF;

  v_mcid := NULLIF(pg_catalog.btrim(COALESCE(p_mcid,'')), '');
  IF pg_catalog.upper(COALESCE(v_mcid,'')) IN ('XXX','N/A','NA','SEM MCID','NÃO POSSUI','NAO POSSUI','-')
    THEN v_mcid := NULL; END IF;
  v_cnpj := NULLIF(pg_catalog.regexp_replace(COALESCE(p_cnpj,''),'[^0-9]','','g'), '');
  IF v_cnpj IS NOT NULL AND pg_catalog.length(v_cnpj) <> 14 THEN
    RAISE EXCEPTION 'CNPJ deve conter 14 dígitos, ou ficar em branco quando houver MCID';
  END IF;
  IF v_mcid IS NULL AND v_cnpj IS NULL THEN
    RAISE EXCEPTION 'Sem MCID, é obrigatório informar o CNPJ';
  END IF;
  v_situacao := NULLIF(pg_catalog.btrim(COALESCE(p_situacao_conta,'')), '');
  IF v_situacao IS NOT NULL AND v_situacao NOT IN
    ('Conta não criada','Criação em andamento','Criação bloqueada','Conta ativa') THEN
    RAISE EXCEPTION 'Situação da conta inválida';
  END IF;
  IF v_mcid IS NULL AND v_situacao = 'Conta ativa' THEN
    RAISE EXCEPTION 'Uma conta sem MCID não pode ser marcada como ativa neste fluxo';
  END IF;

  -- Serializa cadastros assistidos concorrentes para o mesmo MCID/CNPJ.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'sellerpro-forms-loja:' || COALESCE(pg_catalog.upper(v_mcid),v_cnpj), 0
  ));

  IF p_loja_existente_id IS NOT NULL THEN
    SELECT id,seller_id,mcid,cnpj INTO v_id,v_owner,v_existing_mcid,v_existing_cnpj
      FROM public.lojas_amazon WHERE id = p_loja_existente_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Loja selecionada não existe'; END IF;
    IF v_owner <> v_form.seller_id THEN
      RAISE EXCEPTION 'Loja vinculada a outra pessoa. Confira o seller.';
    END IF;
    IF v_mcid IS NOT NULL AND v_existing_mcid IS NOT NULL
      AND pg_catalog.upper(pg_catalog.btrim(v_mcid)) <> pg_catalog.upper(pg_catalog.btrim(v_existing_mcid)) THEN
      RAISE EXCEPTION 'O MCID informado difere da loja selecionada';
    END IF;
    IF v_cnpj IS NOT NULL AND v_existing_cnpj IS NOT NULL
      AND pg_catalog.regexp_replace(v_existing_cnpj,'[^0-9]','','g') <> v_cnpj THEN
      RAISE EXCEPTION 'O CNPJ informado difere da loja selecionada';
    END IF;
  ELSE
    IF v_mcid IS NOT NULL THEN
      SELECT COUNT(*) INTO v_count FROM public.lojas_amazon
        WHERE pg_catalog.upper(pg_catalog.btrim(COALESCE(mcid,''))) = pg_catalog.upper(v_mcid);
      IF v_count > 1 THEN RAISE EXCEPTION 'MCID duplicado no banco; confira as lojas antes de continuar'; END IF;
      IF v_count = 1 THEN
        SELECT id,seller_id INTO v_id,v_owner FROM public.lojas_amazon
          WHERE pg_catalog.upper(pg_catalog.btrim(COALESCE(mcid,''))) = pg_catalog.upper(v_mcid) LIMIT 1;
        IF v_owner <> v_form.seller_id THEN RAISE EXCEPTION 'Este MCID pertence a outra pessoa'; END IF;
      END IF;
    ELSE
      -- Sem MCID, não misturar lojas diferentes pelo CNPJ automaticamente.
      SELECT COUNT(*) INTO v_count FROM public.lojas_amazon
        WHERE pg_catalog.regexp_replace(COALESCE(cnpj,''),'[^0-9]','','g') = v_cnpj;
      IF v_count > 0 THEN
        -- Para reutilizar uma loja já conhecida, o analista deve selecioná-la no formulário.
        RAISE EXCEPTION 'CNPJ já cadastrado. Selecione a loja existente após conferir a pessoa.';
      END IF;
    END IF;

    IF v_id IS NULL THEN
      INSERT INTO public.lojas_amazon(seller_id,mcid,nome_loja,cnpj,email_conta,situacao_conta)
        VALUES (v_form.seller_id,v_mcid,NULLIF(pg_catalog.btrim(COALESCE(p_nome_loja,'')),''),
                v_cnpj,NULLIF(pg_catalog.lower(pg_catalog.btrim(COALESCE(p_email_conta,''))),''),v_situacao)
        RETURNING id INTO v_id;
      v_criado := true;
    END IF;
  END IF;

  UPDATE public.entradas_forms SET loja_id = v_id WHERE id = p_entrada_id;
  RETURN pg_catalog.jsonb_build_object('loja_id',v_id,'criado',v_criado,'ja_vinculado',false);
END;
$$;

REVOKE ALL ON FUNCTION public.forms_confirmar_seller(uuid,text,text,text,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.forms_vincular_loja(uuid,text,text,text,text,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forms_confirmar_seller(uuid,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.forms_vincular_loja(uuid,text,text,text,text,text,uuid) TO authenticated;

COMMENT ON FUNCTION public.forms_confirmar_seller(uuid,text,text,text,uuid) IS
  'Confirma seller (criação ou vínculo) por resposta do Forms; não cria chamados.';
COMMENT ON FUNCTION public.forms_vincular_loja(uuid,text,text,text,text,text,uuid) IS
  'Cria ou vincula loja na pessoa confirmada; preserva o MCID NULL e não cria chamados.';
COMMIT;

-- Verificação: estrutura nova sem expor dados pessoais
SELECT column_name FROM information_schema.columns WHERE table_schema='public'
  AND table_name IN ('entradas_forms','lojas_amazon')
  AND column_name IN ('seller_id','loja_id','situacao_conta')
ORDER BY column_name;
