# Conferências realizadas nesta versão

- `node --check`: interface (`js/app.js`) e script Apps Script passaram na análise sintática.
- `TypeScript compiler`: Edge Function passou na análise sintática.
- Webhook simulado com resposta fictícia da planilha antiga: HTTP 200, `origem_tipo=historico`, `status=arquivado`.
- Webhook simulado com resposta fictícia da planilha nova: HTTP 200, `origem_tipo=novo`, `status=pendente`.
- Webhook simulado de terceira planilha: HTTP 422, origem não permitida.
- Evento Apps Script simulado: a planilha nova dispara o envio; a antiga é bloqueada para envios automáticos.
- Teste de timestamp: a data original do formulário é preservada se disponível.

**Ainda não realizado:** leitura direta das planilhas Google ao vivo; implantação no Supabase `qpczaqrnxjncetotuhwl`; autorização real do Apps Script; execução SQL no banco e teste ponta a ponta no navegador.

O pacote não contém nem publica dados reais dos sellers.
