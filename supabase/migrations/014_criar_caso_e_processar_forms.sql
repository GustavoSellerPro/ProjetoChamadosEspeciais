-- Seller Pro v0.24 - Criação do caso e processamento do formulário, atômicos.
-- EXECUTE APENAS NO PROJETO DE TESTES qpczaqrnxjncetotuhwl.
-- Requer: migrações 009, 011, 012 e a função private.usuario_ativo() da correção 013.
-- Não apaga registros, não cria tickets no Zendesk; registra IDs de tickets já abertos.
BEGIN;

CREATE OR REPLACE FUNCTION public.forms_criar_caso_processar(
  p_entrada_id uuid,
  p_caso_existente_id uuid DEFAULT NULL,
  p_titulo text DEFAULT NULL,
  p_resumo text DEFAULT NULL,
  p_descricao_original text DEFAULT NULL,
  p_status text DEFAULT 'Aguardando Amazon',
  p_categoria_id uuid DEFAULT NULL,
  p_observacoes_internas text DEFAULT NULL,
  p_importante_reuniao boolean DEFAULT false,
  p_tickets text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_form public.entradas_forms%ROWTYPE;
  v_case_id uuid;
  v_raw_ticket text;
  v_ticket text;
  v_existing_ticket_case uuid;
  v_seen text[] := ARRAY[]::text[];
  v_ticket_count integer := 0;
  v_created boolean := false;
  v_status text;
  v_title text;
BEGIN
  IF (SELECT private.usuario_ativo()) IS NOT TRUE THEN
    RAISE EXCEPTION 'Usuário não autorizado';
  END IF;

  -- Lock no Forms impede duplo clique/duas abas de gerar dois casos.
  SELECT * INTO v_form
  FROM public.entradas_forms
  WHERE id = p_entrada_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Formulário não encontrado'; END IF;
  IF v_form.origem_tipo <> 'novo' THEN
    RAISE EXCEPTION 'Registros do histórico antigo são somente para consulta';
  END IF;

  -- Nova tentativa depois de sucesso retorna o mesmo caso, sem duplicar.
  IF v_form.status = 'processado' AND v_form.chamado_id IS NOT NULL THEN
    RETURN pg_catalog.jsonb_build_object(
      'chamado_id', v_form.chamado_id,
      'processado', true,
      'caso_criado', false,
      'ja_processado', true
    );
  END IF;
  IF v_form.status <> 'pendente' THEN
    RAISE EXCEPTION 'Somente formulário pendente pode ser processado';
  END IF;
  IF v_form.seller_id IS NULL OR v_form.loja_id IS NULL THEN
    RAISE EXCEPTION 'Cadastre/vincule o seller e a loja antes de abrir o caso';
  END IF;
  PERFORM 1 FROM public.lojas_amazon
    WHERE id = v_form.loja_id AND seller_id = v_form.seller_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'A loja não pertence à pessoa vinculada ao formulário';
  END IF;

  IF p_caso_existente_id IS NOT NULL AND v_form.chamado_id IS NOT NULL
     AND p_caso_existente_id <> v_form.chamado_id THEN
    RAISE EXCEPTION 'O formulário já está associado a outro caso';
  END IF;

  v_case_id := COALESCE(v_form.chamado_id, p_caso_existente_id);
  IF v_case_id IS NOT NULL THEN
    PERFORM 1 FROM public.chamados
    WHERE id = v_case_id
      AND loja_id = v_form.loja_id
      AND seller_id = v_form.seller_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'O caso selecionado não pertence à pessoa e loja deste formulário';
    END IF;
    IF NULLIF(pg_catalog.btrim(COALESCE(p_tickets,'')),'') IS NOT NULL THEN
      RAISE EXCEPTION 'Para vincular um caso existente, adicione os tickets na ficha do caso após processar';
    END IF;
  ELSE
    v_title := pg_catalog.btrim(COALESCE(p_titulo,''));
    v_status := pg_catalog.btrim(COALESCE(p_status,''));
    IF pg_catalog.length(v_title) < 3 OR pg_catalog.length(v_title) > 200 THEN
      RAISE EXCEPTION 'Informe um título entre 3 e 200 caracteres';
    END IF;
    IF v_status NOT IN ('Aguardando Amazon','Pendente Seller','Finalizado') THEN
      RAISE EXCEPTION 'Status do caso inválido';
    END IF;

    INSERT INTO public.chamados (
      titulo, seller_id, loja_id, status, resumo, descricao_original,
      observacoes_internas, categoria_id, importante_reuniao
    ) VALUES (
      v_title, v_form.seller_id, v_form.loja_id, v_status,
      NULLIF(pg_catalog.btrim(COALESCE(p_resumo,'')),''),
      NULLIF(pg_catalog.btrim(COALESCE(p_descricao_original,'')),''),
      NULLIF(pg_catalog.btrim(COALESCE(p_observacoes_internas,'')),''),
      p_categoria_id, COALESCE(p_importante_reuniao,false)
    ) RETURNING id INTO v_case_id;
    v_created := true;

    -- IDs Zendesk opcionais (não abrem chamados externos). Até 20 por formulário.
    IF NULLIF(pg_catalog.btrim(COALESCE(p_tickets,'')),'') IS NOT NULL THEN
      FOR v_raw_ticket IN
        SELECT pg_catalog.unnest(pg_catalog.regexp_split_to_array(p_tickets,'[,;/[:space:]]+'))
      LOOP
        v_ticket := pg_catalog.btrim(COALESCE(v_raw_ticket,''), ' #');
        IF v_ticket = '' THEN CONTINUE; END IF;
        IF v_ticket !~ '^[0-9]{3,20}$' THEN
          RAISE EXCEPTION 'Número de ticket inválido: % (use apenas IDs numéricos separados por /, vírgula ou espaço)', v_ticket;
        END IF;
        IF v_ticket = ANY(v_seen) THEN CONTINUE; END IF;
        v_seen := pg_catalog.array_append(v_seen,v_ticket);
        v_ticket_count := v_ticket_count + 1;
        IF v_ticket_count > 20 THEN
          RAISE EXCEPTION 'Limite de 20 números de ticket por formulário';
        END IF;
        SELECT chamado_id INTO v_existing_ticket_case
          FROM public.tickets_zendesk WHERE ticket_id::text = v_ticket LIMIT 1;
        IF FOUND THEN
          RAISE EXCEPTION 'O ticket % já está registrado em outro caso. Remova-o deste formulário e confira o caso existente.', v_ticket;
        END IF;
        INSERT INTO public.tickets_zendesk(chamado_id,ticket_id,url_ticket)
        VALUES(v_case_id,v_ticket,
          'https://amazonlatam.zendesk.com/hc/pt-br/requests/' || v_ticket);
      END LOOP;
    END IF;
  END IF;

  -- Os vínculos e o status só persistem se TODAS as etapas anteriores funcionarem.
  UPDATE public.entradas_forms
     SET chamado_id = v_case_id,
         status = 'processado',
         processado_em = pg_catalog.now()
   WHERE id = p_entrada_id;

  RETURN pg_catalog.jsonb_build_object(
    'chamado_id',v_case_id,
    'processado',true,
    'caso_criado',v_created,
    'ja_processado',false,
    'tickets_cadastrados',v_ticket_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.forms_criar_caso_processar(
  uuid,uuid,text,text,text,text,uuid,text,boolean,text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forms_criar_caso_processar(
  uuid,uuid,text,text,text,text,uuid,text,boolean,text
) TO authenticated;

COMMENT ON FUNCTION public.forms_criar_caso_processar(
  uuid,uuid,text,text,text,text,uuid,text,boolean,text
) IS 'Seller Pro v0.24: vincula caso da mesma loja ou cria novo caso e tickets opcionais, processando o Forms na mesma transação';
COMMIT;

-- Verificação de disponibilidade, sem executar chamadas nem expor dados de sellers.
SELECT to_regprocedure('public.forms_criar_caso_processar(uuid,uuid,text,text,text,text,uuid,text,boolean,text)') AS funcao,
       has_function_privilege('authenticated',
        'public.forms_criar_caso_processar(uuid,uuid,text,text,text,text,uuid,text,boolean,text)', 'EXECUTE') AS acesso_autenticado;
