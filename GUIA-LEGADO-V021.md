# Seller Pro — Integração automática Google Forms → Central de Chamados (v0.21)

**Estado do pacote:** código preparado, **não está conectado ao Google automaticamente**. Um administrador precisa publicar a Edge Function e autorizar o acionador na planilha de respostas. Não há tokens privilegiados no frontend. Ambiente **somente de testes**.

## O fluxo
1. Seller envia o Google Forms.
2. Google Sheets recebe a resposta; um acionador de Apps Script envia o evento à Edge Function.
3. `receber-formulario` valida segredo, origem e dados; insere em `public.entradas_forms` com `status = pendente`.
4. Na Central Seller Pro, **Formulários pendentes** exibe a entrada, com consulta paginada para histórias maiores que 500 respostas (atualização automática a cada 60 s enquanto a tela estiver aberta; também há botão Atualizar fila).
5. O analista confere MCID, cadastro e anexos, cria o caso manualmente e vincula a resposta. **Não abre ticket Zendesk automaticamente.**

**Não é necessário habilitar a Google Forms REST API no Google Cloud** para este fluxo. A planilha de respostas + Apps Script com um acionador instalado já fornecem a integração automática via webhook.

## Etapa A — Supabase de TESTES

Acesse o projeto `qpczaqrnxjncetotuhwl` (confira a URL antes de qualquer alteração). **Não mexer em produção.**

1. SQL Editor: verifique se a tabela `public.entradas_forms` existe. Se ainda não existir, execute **uma vez** o arquivo `supabase/migrations/009_fila_forms_testes.sql` (o pacote já o inclui).
2. No Supabase, abra **Edge Functions → Secrets**.
3. Crie o segredo `FORMS_WEBHOOK_SECRET` com uma senha aleatória de pelo menos 32 caracteres (recomendado 64 caracteres ou mais). Guarde esse valor em um gerenciador de senhas. Não o envie em chats, não o coloque no GitHub e **não o adicione ao `js/config.js`**.
4. Recomendado: crie também `FORMS_ALLOWED_SPREADSHEETS` com o(s) ID(s) da(s) planilha(s) que recebe(m) respostas, separados por vírgula. Exemplo: URL `https://docs.google.com/spreadsheets/d/IDENTIFICADOR_AQUI/edit` → o ID é `IDENTIFICADOR_AQUI`. Esse controle impede a gravação de respostas de outras planilhas mesmo se alguém tentar reaproveitar a integração. Na ausência dele, o segredo ainda protege o webhook.
5. **Edge Functions → Deploy a new function → Via Editor**. Nome exato `receber-formulario`. Cole o conteúdo de `supabase/functions/receber-formulario/index.ts` e publique.
6. Em **Function Settings**, desligue `Verify JWT with legacy secret` **somente nesta função**, porque o Google Apps Script usa `x-forms-webhook-secret` e a própria função valida esse segredo. As outras funções devem manter suas proteções.
7. A URL da função será:

   `https://qpczaqrnxjncetotuhwl.supabase.co/functions/v1/receber-formulario`

## Etapa B — Google Forms / Google Sheets

1. Abra o **Google Forms** que recebe os chamados.
2. Vá em **Respostas → Vincular ao Planilhas Google** (ou abra a planilha já vinculada).
3. Dentro da **planilha de respostas**, selecione **Extensões → Apps Script**. NÃO instale o script diretamente no editor do Google Forms — este script usa o acionador da planilha.
4. Cole `integracoes/google-forms/Code.gs` no arquivo `Code.gs`. Salve.
5. No Apps Script, abra **Configurações do projeto → Propriedades do script** e crie:

   | Nome | Valor |
   | --- | --- |
   | `WEBHOOK_URL` | `https://qpczaqrnxjncetotuhwl.supabase.co/functions/v1/receber-formulario` |
   | `FORMS_WEBHOOK_SECRET` | **exatamente o mesmo segredo** configurado no Supabase |
   | `SHEETS_TO_SYNC` *(opcional)* | `Respostas ao formulário 1;Respostas ao formulário 2` |

6. No editor do Apps Script, selecione a função `instalarGatilho` e clique em **Executar**. Conceda as permissões à conta Google que administra a planilha. Isso cria um acionador **Da planilha → Ao enviar formulário** sem duplicar se já estiver instalado.
7. Envie **uma resposta fictícia** pelo formulário original. NÃO execute `onFormSubmit` manualmente (ele depende do evento recebido do Google).
8. Na Central Seller Pro, abra **Formulários pendentes** e clique em **Atualizar fila**. Deve aparecer o registro com `status = pendente`.

**Se existem DOIS formulários conectados a planilhas DIFERENTES**, repita a etapa B em cada planilha. Se os dois estão em abas da mesma planilha, um único acionador basta, desde que o nome de cada aba conste em `SHEETS_TO_SYNC`.

## Etapa C — Histórico antigo (opcional, requer execução manual)

O histórico não será importado automaticamente. Para enviar registros antigos de uma aba de respostas:
1. Faça backup da planilha, confirme que pode tratar esses dados no projeto de testes e revise as permissões de acesso aos documentos do Drive.
2. No Apps Script da planilha de respostas, execute `importarHistorico` manualmente.
3. O script importa até **100 linhas por execução** e registra no log qual linha ficou pendente. Repita até aparecer `Concluído`.
4. Chaves estáveis `gsheet:planilha:aba:linha` evitam duplicatas mesmo após reexecução. **Não altere a ordem das linhas da planilha durante a importação.**

## Diagnóstico

- **Nada chega:** confirme a URL e o segredo em ambas as plataformas, se o acionador existe, e consulte **Apps Script → Execuções** e **Supabase → Edge Functions → Logs**.
- **HTTP 401:** segredos diferentes ou segredo curto.
- **HTTP 422:** payload inválido, fonte não permitida ou aba/ID incorreto.
- **HTTP 500:** a tabela `entradas_forms` não existe ou houve erro de permissão no banco. Confirme a migração 009 e políticas RLS.
- **Aparece na tabela, mas não na Central:** recarregue a página, confira login e políticas RLS da tabela `entradas_forms`. Se a lista estiver filtrada, mude para `Todos`.
- **Google Drive:** links de documentos são preservados na resposta, mas o sistema **não altera o compartilhamento** desses arquivos.

## Segurança

- Não publique a chave `service_role` / `sb_secret_...` nem o `FORMS_WEBHOOK_SECRET` no site/GitHub.
- Configure o segredo somente em **Edge Functions → Secrets** e **Apps Script → Propriedades do script**.
- Dados reais incluem identificadores fiscais, nomes, e-mails, telefones, documentos e detalhes de chamados. Limite o acesso conforme suas políticas internas/LGPD.
- Nenhum cliente será criado automaticamente; um analista deverá revisar e associar cada entrada ao caso correto.
- **Somente a instância de TESTES** está configurada. Não use o projeto de produção até validar tudo.

## O que mudou em relação à v0.20
- Nova Edge Function `receber-formulario` compatível com `entradas_forms` (a versão antiga escrevia em outra tabela).
- Novo Apps Script compatível com novas respostas e importação retroativa controlada.
- Tela da Central atualizada para mostrar contagem real de pendências e atualizar enquanto estiver aberta.
- Sem alterações em autenticação, reset de senha, reuniões, dashboards, tickets, logos ou outras telas.
