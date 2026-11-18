# Seller Pro — v0.22: duas planilhas Google Forms, duas rotas distintas

**Status:** pacote preparado para implantação no Supabase de **TESTES** (`qpczaqrnxjncetotuhwl`). Não há acesso autorizado à sua conta Google ou a esse projeto de testes a partir deste ambiente; a publicação do acionador Google e da Edge Function ainda precisa ser feita por um administrador. Não altere produção.

## Planilhas cadastradas

- **Histórico antigo:** https://docs.google.com/spreadsheets/d/1bQZRKsvnFfEjp4BRB4ZGX3nf1U8dTQvoZc9itxGb_Bo/edit
- **Formulário novo:** https://docs.google.com/spreadsheets/d/1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ/edit

Esses links identificam as fontes. Não consegui ler diretamente seu conteúdo atual pela conta Google; a correspondência de campos foi conferida nos arquivos Excel fornecidos antes. **Confirme o nome da aba de respostas** ao configurar o Apps Script.

## Comportamento pretendido

| Origem | Quando enviar | Status na tabela | Na interface |
|---|---|---|---|
| Planilha NOVA | Automaticamente a cada resposta | `pendente` | **Novas solicitações**, com conferência manual |
| Planilha ANTIGA | Apenas quando ADM optar por importar histórico | `arquivado` | **Histórico antigo**, pesquisa por MCID/nome/resumo |

O registro mantém as perguntas e respostas originais, inclusive links de Drive. O importador usa `gsheet:ID_planilha:ID_aba:numero_da_linha` para evitar importação duplicada. Não reorganize ou classifique as linhas na planilha de origem durante o importador.

## Etapa 1 — banco (somente Supabase de TESTES)

1. Faça backup/verifique a necessidade de importar dados pessoais reais para o ambiente de testes e os acessos da equipe.
2. Entre em https://supabase.com/dashboard/project/qpczaqrnxjncetotuhwl/sql/new
3. Se a tabela `entradas_forms` ainda não existir, rode a migração **009_fila_forms_testes.sql** (uma única vez).
4. Execute a nova migração **011_separar_formularios_historico_novo.sql**.
5. Rode o SELECT de verificação no final da 011. Se houve importação antiga pela v0.21, os registros antigos pendentes serão marcados `arquivado` e não entrarão no total de pendências novas.

## Etapa 2 — Edge Function e segredos (somente TESTES)

1. **Edge Functions → Secrets**, mantenha `FORMS_WEBHOOK_SECRET` com valor forte e único (>=32 caracteres).
2. Crie/atualize `FORMS_ALLOWED_SPREADSHEETS` com **exatamente** os dois IDs, separados por vírgula:

   `1bQZRKsvnFfEjp4BRB4ZGX3nf1U8dTQvoZc9itxGb_Bo,1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ`

3. Atualize a função `receber-formulario` colando `supabase/functions/receber-formulario/index.ts` e publicando.
4. Mantenha `verify_jwt` **desligado apenas nessa função de webhook**, pois seu código confere `x-forms-webhook-secret`. As outras funções não devem ser alteradas.
5. URL da função:

   `https://qpczaqrnxjncetotuhwl.supabase.co/functions/v1/receber-formulario`

**Não cole `FORMS_WEBHOOK_SECRET` no frontend, no GitHub nem no chat.** A classificação como antigo/novo é feita pela Edge Function pelo ID da planilha, não por um campo editável do navegador.

## Etapa 3 — planilha NOVA (integração automática)

1. Abra https://docs.google.com/spreadsheets/d/1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ/edit
2. Clique **Extensões → Apps Script**.
3. Cole todo o conteúdo `integracoes/google-forms/Code.gs`.
4. Em **Configurações do projeto → Propriedades do script**, adicione:

   - `WEBHOOK_URL` = `https://qpczaqrnxjncetotuhwl.supabase.co/functions/v1/receber-formulario`
   - `FORMS_WEBHOOK_SECRET` = o valor definido no Supabase, sem compartilhar com terceiros
   - `SHEETS_TO_SYNC` = nome **exato** da aba que recebe as respostas (nos arquivos exportados, aparece `Respostas ao formulário 1`)

5. Salve. No seletor de funções do Apps Script, execute `instalarGatilho` **uma única vez** e autorize o acesso. Isso instala o acionador **Da planilha → Ao enviar formulário**.
6. Envie uma resposta **nova de teste** pelo Google Forms. Confirme a nova linha na planilha e verifique a entrada em **Novas solicitações** na Central Seller Pro.
7. A resposta de teste antiga que já estava na planilha não dispara o acionador retrospectivamente. Para inseri-la na fila, rode **uma única vez** `importarTesteNovo` (idempotente). Ela será `pendente` para conferência.

## Etapa 4 — planilha ANTIGA (importação sob demanda, SEM acionador)

**Não instale gatilho na planilha antiga.** O script bloqueia essa tentativa intencionalmente. Caso você já tenha instalado um gatilho da versão 0.21 na planilha antiga, abra **Apps Script → Acionadores** e exclua o gatilho `onFormSubmit` dessa planilha antes da importação manual.

1. Depois de confirmar que o novo está funcionando e que é adequado importar os dados históricos para o projeto de testes, abra: https://docs.google.com/spreadsheets/d/1bQZRKsvnFfEjp4BRB4ZGX3nf1U8dTQvoZc9itxGb_Bo/edit
2. Faça um backup da planilha antes de iniciar.
3. **Extensões → Apps Script** → cole `Code.gs` (pode ser igual ao usado na nova).
4. Configure `WEBHOOK_URL` e `FORMS_WEBHOOK_SECRET` iguais aos usados na nova. Em `SHEETS_TO_SYNC`, coloque o nome **exato** da aba antiga (nos arquivos exportados, é `Respostas ao formulário 1`).
5. Execute **apenas** `importarHistorico` manualmente, autorizando o Apps Script. Cada execução envia até 100 linhas e indica em **Execuções/Logs** se deve repetir.
6. Repita até o log registrar **Concluído**. A importação não cria cases, sellers ou tickets; tudo entra em **Histórico antigo** com status `arquivado`.

O arquivo Excel antigo disponibilizado anteriormente continha centenas de respostas. Este pacote **não copia** essas respostas; elas só entram após sua execução manual autorizada. Documentos do Drive continuam sujeitos às permissões originais.

## Etapa 5 — publicar frontend de TESTES

Substitua os arquivos anteriores da branch **`dev`** pelos da pasta deste pacote. Não altere `main` nem o Supabase principal.

Na Central, abra **Formulários pendentes**: duas abas aparecerão:

- **Novas solicitações:** pendente/processado, com botão **Conferir** e vínculo ao caso.
- **Histórico antigo:** consulta por pesquisa; não oferece botão de processamento.

## Diagnóstico e segurança

- **Erro 401** no Apps Script: segredo incorreto; confira o valor nos dois lados.
- **Erro 422**: planilha não corresponde a um dos dois IDs, aba ou payload incorretos.
- **Erro 500**: aplique a 009 e a 011 e verifique Logs da função Supabase.
- **Nada acontece na nova**: verifique **Apps Script → Acionadores** e **Execuções**, nome da aba, se houve uma resposta NOVA (não apenas abertura da planilha), e logs da Edge Function.
- **Histórico aparece como pendente:** reexecute/verifique a migração 011 no projeto de testes. **Não** tente corrigir na planilha por exclusão de linhas.
- **Histórico real:** controle acessos e política de retenção e proteção de dados. Evite importar em projeto de teste compartilhado sem autorização.

Não há necessidade de habilitar Google Forms API no Cloud Console: o acionador de planilha e o webhook fazem a integração.
