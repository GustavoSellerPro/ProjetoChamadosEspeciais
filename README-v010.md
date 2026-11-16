# Seller Pro — v0.10 (somente testes)

Esta versão mantém a conexão SOMENTE com qpczaqrnxjncetotuhwl.supabase.co.

## Passos
1. Supabase de TESTES → SQL Editor: executar `supabase/migrations/009_fila_forms_testes.sql`. Não executar na produção.
2. Abrir `index.html` no Live Server; acessar com conta de teste.
3. Testar **Voltar ao login** na troca obrigatória de senha (não apaga a conta nem conclui a troca).
4. Clicar nos cinco indicadores do dashboard: abre modal filtrado.
5. Abrir **Reuniões Amazon** no menu: lista chamados marcados.
6. Abrir **Formulários pendentes**: a fila fica vazia até que o webhook seja conectado; isso é esperado.
7. Somente após testar fazer commit na branch `dev`. NÃO subir para main.

## Google Forms: decisão de integração
Vamos usar Apps Script da planilha → Edge Function autenticada por segredo → `entradas_forms`, com `origem_id` único. Não existe essa Edge Function de entrada implantada neste pacote. Não configurar o acionador antes da próxima etapa. A fila não cria sellers, lojas ou casos sozinha.

## Segurança
Usar somente contas fictícias. A tabela de fila tem RLS e leitura/atualização somente para usuários ativos sem senha pendente. A inserção deve acontecer exclusivamente via backend autorizado (service_role); nenhuma chave secreta deve ser exposta em JS. A UI não substitui auditoria de acesso, validação de MCID, permissões de Drive ou política LGPD.

## Observação
O vínculo do formulário a um caso requer seleção explícita de caso com MCID correspondente; nenhuma deduplicação automática está ativa.
