-- Seller Pro v0.25: cadastro automatico CONSERVADOR ao inserir Forms NOVOS.
-- Executar somente no TESTE: qpczaqrnxjncetotuhwl.
-- Depende das migracoes 009, 011, 012, 013 e 014. Sem alterar Apps Script/Edge Function.
-- Nao abre chamado, nao fecha formulario, nao altera historico antigo, nunca grava 'XXX' no MCID.
BEGIN;

ALTER TABLE public.entradas_forms
  ADD COLUMN IF NOT EXISTS cadastro_status text NOT NULL DEFAULT 'aguardando';
ALTER TABLE public.entradas_forms
  ADD COLUMN IF NOT EXISTS cadastro_motivo text;
ALTER TABLE public.entradas_forms
  ADD COLUMN IF NOT EXISTS cadastro_atualizado_em timestamptz;
ALTER TABLE public.entradas_forms DROP CONSTRAINT IF EXISTS entradas_forms_cadastro_status_check;
ALTER TABLE public.entradas_forms ADD CONSTRAINT entradas_forms_cadastro_status_check
  CHECK (cadastro_status IN ('aguardando','automatico','revisao','manual','nao_aplicavel'));

UPDATE public.entradas_forms SET cadastro_status='nao_aplicavel'
 WHERE origem_tipo='historico' AND cadastro_status='aguardando';
UPDATE public.entradas_forms SET cadastro_status='manual', cadastro_atualizado_em=now()
 WHERE origem_tipo='novo' AND (seller_id IS NOT NULL OR loja_id IS NOT NULL)
   AND cadastro_status='aguardando';

COMMENT ON COLUMN public.entradas_forms.cadastro_status IS
 'automatico=identidade/loja vinculadas no webhook; revisao=exige analista; manual=concluido parcialmente ou totalmente pela equipe; nao_aplicavel=historico antigo';

-- Campos do Google podem ter enunciados longos; localiza por prefixo normalizado.
CREATE OR REPLACE FUNCTION private.forms_campo(p_respostas jsonb, p_prefixos text[])
RETURNS text LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=''
AS $$
DECLARE v_prefix text; v_value text;
BEGIN
  FOREACH v_prefix IN ARRAY p_prefixos LOOP
    SELECT NULLIF(pg_catalog.btrim(e.value),'') INTO v_value
      FROM pg_catalog.jsonb_each_text(COALESCE(p_respostas,'{}'::jsonb)) AS e(key,value)
      WHERE pg_catalog.regexp_replace(
              pg_catalog.translate(pg_catalog.lower(e.key),
                'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),
              '[^a-z0-9]+',' ','g')
            LIKE pg_catalog.regexp_replace(
              pg_catalog.translate(pg_catalog.lower(v_prefix),
                'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),
              '[^a-z0-9]+',' ','g') || '%'
      ORDER BY CASE WHEN pg_catalog.lower(e.key)=pg_catalog.lower(v_prefix) THEN 0 ELSE 1 END,
               pg_catalog.length(e.key), e.key
      LIMIT 1;
    IF v_value IS NOT NULL THEN RETURN v_value; END IF;
  END LOOP;
  RETURN NULL;
END;
$$;

-- Invoker: insercao do Forms ocorre com service_role; sem SECURITY DEFINER e sem liberar ao anon/authenticated.
-- Protege erros/concorrencia e nao cria cadastros diante de campos conflitantes.
CREATE OR REPLACE FUNCTION private.forms_auto_vincular(p_entrada_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
DECLARE
  f public.entradas_forms%ROWTYPE;
  v_nome text; v_email text; v_phone text; v_phone_digits text;
  v_mcid text; v_raw_mcid text; v_cnpj text; v_nome_loja text;
  v_seller_id uuid; v_loja_id uuid; v_email_owner uuid; v_phone_owner uuid;
  v_store public.lojas_amazon%ROWTYPE;
  v_owner public.sellers%ROWTYPE;
  v_count integer; v_email_count integer; v_phone_count integer;
  v_reason text; v_phone_ok boolean; v_created_seller boolean := false;
  v_created_store boolean := false; v_mcid_upgrade boolean := false;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sellerpro-forms-auto-cadastro',0));
  SELECT * INTO f FROM public.entradas_forms WHERE id=p_entrada_id FOR UPDATE;
  IF NOT FOUND THEN RETURN pg_catalog.jsonb_build_object('resultado','nao_encontrado'); END IF;
  IF f.origem_tipo <> 'novo' OR f.origem_id NOT LIKE 'gsheet:1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ:%' THEN
    RETURN pg_catalog.jsonb_build_object('resultado','ignorado_historico');
  END IF;
  IF f.status <> 'pendente' THEN RETURN pg_catalog.jsonb_build_object('resultado','ignorado_processado'); END IF;
  IF f.seller_id IS NOT NULL OR f.loja_id IS NOT NULL THEN
    UPDATE public.entradas_forms SET cadastro_status=CASE WHEN cadastro_status='automatico' THEN 'automatico' ELSE 'manual' END,
      cadastro_atualizado_em=pg_catalog.now() WHERE id=f.id;
    RETURN pg_catalog.jsonb_build_object('resultado','ja_vinculado');
  END IF;

  -- Bloco interno com rollback automatico se alguma gravacao falhar.
  BEGIN
    v_nome:=NULLIF(pg_catalog.btrim(COALESCE(private.forms_campo(f.respostas,ARRAY['Nome Completo','Seu nome inteiro']),f.nome,'')),'');
    v_email:=NULLIF(pg_catalog.lower(pg_catalog.btrim(COALESCE(private.forms_campo(f.respostas,
      ARRAY['Endereço de Email da sua Conta Amazon','Email da sua Conta Amazon','E-mail','Email']),''))),'');
    v_phone:=NULLIF(pg_catalog.btrim(COALESCE(private.forms_campo(f.respostas,
      ARRAY['Telefone de Contato','Telefone / WhatsApp','Telefone Cadastrado na Amazon','Telefone']),'')),'');
    v_phone_digits:=pg_catalog.regexp_replace(COALESCE(v_phone,''),'[^0-9]','','g');
    v_phone_ok:=pg_catalog.length(v_phone_digits) BETWEEN 10 AND 13;
    v_raw_mcid:=pg_catalog.upper(pg_catalog.btrim(COALESCE(private.forms_campo(f.respostas,
      ARRAY['MCID','Codigo do vendedor']),f.mcid,'')));
    v_mcid:=NULLIF(v_raw_mcid,'');
    IF v_mcid IN ('XXX','XXXX','N/A','NA','SEM MCID','NÃO POSSUI','NAO POSSUI',
      'NÃO APLICÁVEL','NAO APLICAVEL','NÃO TENHO','NAO TENHO','NÃO POSSUO',
      'NAO POSSUO','PENDENTE','-','0') THEN v_mcid:=NULL; END IF;
    v_cnpj:=NULLIF(pg_catalog.regexp_replace(COALESCE(private.forms_campo(f.respostas,
      ARRAY['Número CNPJ','CNPJ']),''),'[^0-9]','','g'),'');
    v_nome_loja:=NULLIF(pg_catalog.btrim(COALESCE(private.forms_campo(f.respostas,
      ARRAY['Nome da sua Loja Amazon','Nome da loja']),'')),'');

    IF v_nome IS NULL OR pg_catalog.length(v_nome)<3 THEN
      v_reason:='Nome do seller ausente ou muito curto';
    ELSIF v_email IS NOT NULL AND (pg_catalog.length(v_email)>254 OR v_email !~
      '^[a-z0-9][a-z0-9._%+-]*@[a-z0-9-]+([.][a-z0-9-]+)+$') THEN
      v_reason:='E-mail informado fora do padrão';
    ELSIF v_phone IS NOT NULL AND NOT v_phone_ok THEN
      v_reason:='Telefone informado fora do padrão';
    ELSIF v_email IS NULL AND NOT v_phone_ok THEN
      v_reason:='Falta e-mail ou telefone válido para identificar a pessoa';
    ELSIF v_mcid IS NOT NULL AND v_mcid !~ '^[A-Z0-9]{8,40}$' THEN
      v_reason:='MCID informado não parece válido';
    ELSIF v_cnpj IS NOT NULL AND pg_catalog.length(v_cnpj)<>14 THEN
      v_reason:='CNPJ deve conter 14 dígitos';
    ELSIF v_mcid IS NULL AND v_cnpj IS NULL THEN
      v_reason:='Seller sem MCID precisa informar CNPJ para criar uma loja provisória';
    END IF;

    IF v_reason IS NULL THEN
      -- Loja por MCID exato. Quando ausente, so loja PROVISORIA por CNPJ unico.
      IF v_mcid IS NOT NULL THEN
        SELECT pg_catalog.count(*) INTO v_count FROM public.lojas_amazon
         WHERE pg_catalog.upper(pg_catalog.btrim(COALESCE(mcid,'')))=v_mcid;
        IF v_count>1 THEN v_reason:='Mais de uma loja encontrada para este MCID'; END IF;
        IF v_count=1 THEN
          SELECT * INTO v_store FROM public.lojas_amazon
           WHERE pg_catalog.upper(pg_catalog.btrim(COALESCE(mcid,'')))=v_mcid LIMIT 1 FOR UPDATE;
        ELSIF v_cnpj IS NOT NULL THEN
          -- MCID novo + CNPJ da loja provisoria existente: reusar, mas requer confirmar identidade.
          SELECT pg_catalog.count(*) INTO v_count FROM public.lojas_amazon
           WHERE mcid IS NULL AND pg_catalog.regexp_replace(COALESCE(cnpj,''),'[^0-9]','','g')=v_cnpj;
          IF v_count>1 THEN v_reason:='Várias lojas provisórias com esse CNPJ'; END IF;
          IF v_count=1 THEN
            SELECT * INTO v_store FROM public.lojas_amazon
              WHERE mcid IS NULL AND pg_catalog.regexp_replace(COALESCE(cnpj,''),'[^0-9]','','g')=v_cnpj
              LIMIT 1 FOR UPDATE;
            v_mcid_upgrade:=true;
          END IF;
        END IF;
      ELSE
        SELECT pg_catalog.count(*) INTO v_count FROM public.lojas_amazon
          WHERE pg_catalog.regexp_replace(COALESCE(cnpj,''),'[^0-9]','','g')=v_cnpj;
        IF v_count>1 THEN v_reason:='Mais de uma loja com esse CNPJ'; END IF;
        IF v_count=1 THEN
          SELECT * INTO v_store FROM public.lojas_amazon
           WHERE pg_catalog.regexp_replace(COALESCE(cnpj,''),'[^0-9]','','g')=v_cnpj
           LIMIT 1 FOR UPDATE;
          IF v_store.mcid IS NOT NULL THEN
            v_reason:='CNPJ já está em loja com MCID; conferir se é nova conta';
          END IF;
        END IF;
      END IF;
    END IF;

    -- Correspondencia de pessoa APENAS por email e/ou telefone exatos.
    IF v_reason IS NULL THEN
      IF v_email IS NOT NULL THEN
        SELECT pg_catalog.count(*) INTO v_email_count FROM public.sellers
          WHERE pg_catalog.lower(pg_catalog.btrim(COALESCE(email,'')))=v_email;
        IF v_email_count>1 THEN v_reason:='E-mail encontrado em várias pessoas'; END IF;
        IF v_email_count=1 THEN
          SELECT id INTO v_email_owner FROM public.sellers
           WHERE pg_catalog.lower(pg_catalog.btrim(COALESCE(email,'')))=v_email LIMIT 1;
        END IF;
      END IF;
      IF v_phone_ok THEN
        SELECT pg_catalog.count(*) INTO v_phone_count FROM public.sellers
          WHERE pg_catalog.regexp_replace(COALESCE(telefone,''),'[^0-9]','','g')=v_phone_digits;
        IF v_phone_count>1 THEN v_reason:='Telefone encontrado em várias pessoas'; END IF;
        IF v_phone_count=1 THEN
          SELECT id INTO v_phone_owner FROM public.sellers
           WHERE pg_catalog.regexp_replace(COALESCE(telefone,''),'[^0-9]','','g')=v_phone_digits LIMIT 1;
        END IF;
      END IF;
      IF v_email_owner IS NOT NULL AND v_phone_owner IS NOT NULL
        AND v_email_owner<>v_phone_owner THEN
        v_reason:='E-mail e telefone apontam para pessoas diferentes';
      END IF;
    END IF;

    IF v_reason IS NULL THEN
      IF v_store.id IS NOT NULL THEN
        v_seller_id:=v_store.seller_id;
        SELECT * INTO v_owner FROM public.sellers WHERE id=v_seller_id FOR UPDATE;
        IF NOT FOUND THEN v_reason:='A loja existente não possui pessoa acessível'; END IF;
        IF v_email_owner IS NOT NULL AND v_email_owner<>v_seller_id THEN
          v_reason:='MCID/CNPJ pertence a outra pessoa diferente do e-mail informado';
        END IF;
        IF v_phone_owner IS NOT NULL AND v_phone_owner<>v_seller_id THEN
          v_reason:='MCID/CNPJ pertence a outra pessoa diferente do telefone informado';
        END IF;
        IF NOT (COALESCE(v_email_owner=v_seller_id,false)
          OR COALESCE(v_phone_owner=v_seller_id,false)
          OR (v_email IS NOT NULL AND pg_catalog.lower(pg_catalog.btrim(COALESCE(v_store.email_conta,'')))=v_email)) THEN
          v_reason:='Loja existente: falta confirmação por e-mail ou telefone coincidente';
        END IF;
      ELSE
        v_seller_id:=COALESCE(v_email_owner,v_phone_owner);
        IF v_seller_id IS NOT NULL THEN
          SELECT * INTO v_owner FROM public.sellers WHERE id=v_seller_id FOR UPDATE;
        END IF;
      END IF;
    END IF;

    IF v_reason IS NULL AND v_seller_id IS NOT NULL THEN
      -- Nao sobrescrever campos que ja possuem valores, nem alterar cadastro divergente.
      IF v_email_owner IS NULL AND v_email IS NOT NULL AND v_owner.email IS NOT NULL
        AND pg_catalog.lower(pg_catalog.btrim(v_owner.email))<>v_email THEN
        v_reason:='E-mail divergente da pessoa existente';
      END IF;
      IF v_phone_ok AND v_phone_owner IS NULL AND v_owner.telefone IS NOT NULL
        AND pg_catalog.regexp_replace(v_owner.telefone,'[^0-9]','','g')<>v_phone_digits THEN
        v_reason:='Telefone divergente da pessoa existente';
      END IF;
      IF v_store.id IS NULL AND pg_catalog.lower(pg_catalog.btrim(v_owner.nome))<>
        pg_catalog.lower(pg_catalog.btrim(v_nome)) THEN
        v_reason:='Nome diferente do cadastro existente; conferir identidade';
      END IF;
    END IF;

    IF v_reason IS NULL AND v_store.id IS NOT NULL THEN
      IF v_cnpj IS NOT NULL AND v_store.cnpj IS NOT NULL AND
        pg_catalog.regexp_replace(v_store.cnpj,'[^0-9]','','g')<>v_cnpj THEN
        v_reason:='CNPJ diferente do cadastro da loja';
      END IF;
      IF v_email IS NOT NULL AND v_store.email_conta IS NOT NULL AND
        pg_catalog.lower(pg_catalog.btrim(v_store.email_conta))<>v_email THEN
        v_reason:='E-mail da conta Amazon divergente';
      END IF;
    END IF;

    -- Check extra: MCID novo e mesmo CNPJ em loja ja ativa nao cria loja ambiguamente.
    IF v_reason IS NULL AND v_store.id IS NULL AND v_mcid IS NOT NULL AND v_cnpj IS NOT NULL
      AND EXISTS (SELECT 1 FROM public.lojas_amazon
        WHERE pg_catalog.regexp_replace(COALESCE(cnpj,''),'[^0-9]','','g')=v_cnpj) THEN
      v_reason:='CNPJ usado em outra loja; conferir antes de registrar MCID novo';
    END IF;

    IF v_reason IS NULL THEN
      IF v_seller_id IS NULL THEN
        INSERT INTO public.sellers(nome,email,telefone)
          VALUES(v_nome,v_email,CASE WHEN v_phone_ok THEN v_phone ELSE NULL END)
          RETURNING id INTO v_seller_id;
        v_created_seller:=true;
      ELSE
        UPDATE public.sellers SET
          email=COALESCE(NULLIF(pg_catalog.btrim(email),''),v_email),
          telefone=COALESCE(NULLIF(pg_catalog.btrim(telefone),''),CASE WHEN v_phone_ok THEN v_phone END)
          WHERE id=v_seller_id;
      END IF;

      IF v_store.id IS NULL THEN
        INSERT INTO public.lojas_amazon(seller_id,mcid,nome_loja,cnpj,email_conta,situacao_conta)
          VALUES(v_seller_id,v_mcid,v_nome_loja,v_cnpj,v_email,
                 CASE WHEN v_mcid IS NULL THEN 'Conta não criada' ELSE 'Conta ativa' END)
          RETURNING id INTO v_loja_id;
        v_created_store:=true;
      ELSE
        v_loja_id:=v_store.id;
        UPDATE public.lojas_amazon SET
          mcid=COALESCE(mcid,v_mcid),
          cnpj=COALESCE(NULLIF(pg_catalog.btrim(cnpj),''),v_cnpj),
          nome_loja=COALESCE(NULLIF(pg_catalog.btrim(nome_loja),''),v_nome_loja),
          email_conta=COALESCE(NULLIF(pg_catalog.btrim(email_conta),''),v_email),
          situacao_conta=CASE WHEN v_mcid_upgrade THEN 'Conta ativa'
                             ELSE COALESCE(situacao_conta,
                               CASE WHEN v_mcid IS NULL THEN 'Conta não criada' ELSE 'Conta ativa' END) END
          WHERE id=v_loja_id;
      END IF;
      UPDATE public.entradas_forms
        SET seller_id=v_seller_id,loja_id=v_loja_id,
            cadastro_status='automatico',cadastro_motivo=NULL,cadastro_atualizado_em=pg_catalog.now()
        WHERE id=f.id;
      RETURN pg_catalog.jsonb_build_object('resultado','automatico','seller_criado',v_created_seller,
        'loja_criada',v_created_store,'seller_id',v_seller_id,'loja_id',v_loja_id);
    END IF;

    UPDATE public.entradas_forms SET cadastro_status='revisao',cadastro_motivo=v_reason,
      cadastro_atualizado_em=pg_catalog.now() WHERE id=f.id;
    RETURN pg_catalog.jsonb_build_object('resultado','revisao','motivo',v_reason);
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'forms_auto_vincular - erro SQLSTATE % (sem dados pessoais)', SQLSTATE;
    -- A subtransacao cancela criacoes de pessoa/loja feitas neste bloco em caso de erro.
    UPDATE public.entradas_forms SET cadastro_status='revisao',
      cadastro_motivo='Falha interna de cadastro automático; consulte os logs do banco',
      cadastro_atualizado_em=pg_catalog.now() WHERE id=f.id;
    RETURN pg_catalog.jsonb_build_object('resultado','erro_contido');
  END;
END;
$$;

-- Gatilho em INSERT apenas: ignora reenviar o mesmo Google Forms (origem_id unico).
CREATE OR REPLACE FUNCTION private.forms_auto_gatilho()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$
BEGIN
  IF NEW.origem_tipo='novo' AND NEW.origem_id LIKE 'gsheet:1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ:%' THEN
    PERFORM private.forms_auto_vincular(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS entradas_forms_auto_cadastro_insert ON public.entradas_forms;
CREATE TRIGGER entradas_forms_auto_cadastro_insert
  AFTER INSERT ON public.entradas_forms
  FOR EACH ROW EXECUTE FUNCTION private.forms_auto_gatilho();

-- Permissoes: disponivel SOMENTE ao webhook com service_role (e ao administrador SQL postgres).
REVOKE ALL ON FUNCTION private.forms_campo(jsonb,text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.forms_auto_vincular(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.forms_auto_gatilho() FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT EXECUTE ON FUNCTION private.forms_campo(jsonb,text[]) TO service_role;
GRANT EXECUTE ON FUNCTION private.forms_auto_vincular(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION private.forms_auto_gatilho() TO service_role;

COMMIT;

-- Diagnostico sem dados pessoais:
SELECT cadastro_status, count(*) AS quantidade
FROM public.entradas_forms WHERE origem_tipo='novo'
GROUP BY cadastro_status ORDER BY cadastro_status;
