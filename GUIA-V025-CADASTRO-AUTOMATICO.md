# Seller Pro v0.25 — Pessoa e loja automaticamente, caso após conferência

**Projeto-alvo exclusivamente de TESTES:** `qpczaqrnxjncetotuhwl` (não mexer em `sshhyqywxwpijsosxdvz`).

## Comportamento

1. O Google Forms novo envia a resposta normalmente para a Edge Function `receber-formulario` (já existente).
2. Uma trigger no **banco de testes** identifica a inserção **nova** da planilha permitida e, em uma mesma transação, tenta identificar pessoa e loja.
3. Se as correspondências forem seguras, a Central cria ou reutiliza a pessoa e a loja, vincula ambos à resposta e indica **Cadastro automático**. Só preenche dados vazios dos cadastros existentes. MCID `XXX` nunca é gravado como real: exige CNPJ de 14 dígitos para loja provisória.
4. Dados faltantes/inválidos ou divergências (MCID, CNPJ, e-mail, telefone, vínculo de outra pessoa, várias lojas com mesmo CNPJ) ficam como **Revisão necessária**. A mensagem explica o motivo no pop-up; os botões manuais da v0.24 continuam funcionando.
5. O registro continua **Pendente** até a equipe criar ou vincular o caso com o botão final. Só então fica **Processado**. Nenhum ticket é aberto automaticamente no Zendesk.
6. A planilha histórica permanece *somente leitura*: nenhum cadastro automático.

**Cautela importante:** o formulário contém dados autodeclarados. Por isso, o sistema **não substitui valores já preenchidos de cadastros existentes** e não aceita correspondências conflitantes. E-mail/telefone podem identificar uma pessoa, mas ao associar loja existente exigimos também coincidência segura de dados de contato. Nunca cria caso automaticamente.

## Instalação (na ordem)

1. Confirme que está no projeto Supabase de **TESTES**, que já recebeu as migrações 009, 011, 012, 013 e 014.
2. Execute `supabase/migrations/015_auto_cadastro_forms.sql` no SQL Editor. A query no final mostra somente contagens.
3. Publique os arquivos do site atualizados (`js/app.js`, `css/style.css` e demais do pacote) **na branch de testes `dev`**. Não atualizar `main`.
4. Recarregue a Central (Ctrl+F5); vá em Formulários pendentes → Novas solicitações.
5. **Envie uma nova resposta de teste no formulário novo** com nome, e-mail válido, telefone, MCID ou CNPJ e nome da loja. Confirme que a linha exibe **Cadastro automático**. Abra o pop-up: etapas 1 e 2 vinculadas, etapa 3 (caso) disponível.
6. Faça um segundo teste com e-mail inválido ou CNPJ divergente: a linha deverá mostrar **Revisão necessária** e a mensagem de motivo. Confirme que não surgiram cadastros incorretos.
7. Teste novamente a mesma resposta / integração. O `origem_id` é único e o webhook usa `ignoreDuplicates`: reenvio não deve criar outro seller/loja.
8. Teste a planilha **antiga**: o histórico não deve criar nenhum cadastro.

## Testar com respostas novas que chegaram ANTES da migração

A trigger só processa **novas inserções**, portanto as duas respostas antigas já recebidas não disparam automaticamente. Se quiser reprocessar respostas pendentes antigas que **ainda não têm seller nem loja vinculados**, execute no SQL Editor **de testes** após ter feito backup:

```sql
SELECT f.id, private.forms_auto_vincular(f.id) AS resultado
  FROM public.entradas_forms f
 WHERE f.origem_tipo = 'novo'
   AND f.status = 'pendente'
   AND f.seller_id IS NULL AND f.loja_id IS NULL
   AND f.cadastro_status IN ('aguardando','revisao')
 ORDER BY f.recebido_em
 LIMIT 10;
```

Não executa no histórico. Os que já têm vínculo manual permanecem como estão. O procedimento retorna `automatico`, `revisao` ou `erro_contido`. Se aparecer `erro_contido`, consulte os logs/estrutura do banco: a resposta foi preservada, sem cadastros parcialmente criados.

## Conferência SQL sem mostrar dados pessoais

```sql
SELECT origem_tipo, status, cadastro_status, COUNT(*) AS quantidade
  FROM public.entradas_forms
 GROUP BY origem_tipo, status, cadastro_status
 ORDER BY origem_tipo, status, cadastro_status;
```

## O que não muda

- Não substituir `FORMS_WEBHOOK_SECRET` ou o Apps Script se a integração já estiver recebendo respostas.
- Não redeployar `receber-formulario`, pois a trigger atua no banco quando essa função grava uma resposta nova.
- Não rodar SQL em produção.
- Não é possível testar a gravação real deste ZIP no Supabase do usuário a partir daqui; valide no projeto de TESTES antes de autorizar produção.
