Seller Pro · Central de Chamados — Protótipo v0.1
Abrir
Abra `index.html` em um navegador moderno. É uma aplicação local e demonstrativa, sem login ou backend. A interface dispõe de temas claro e escuro.
Importar dados
Na aba Configurações e integrações, selecione o tipo e escolha o arquivo XLSX original:
`Tickets programa BETA suporte Mentor.xlsx`: somente a aba `Chamados Abertos` (não importa `Chamados Abertos_01`).
`Formulário de Chamados Especiais (respostas).xlsx`: somente a aba `Respostas ao formulário 1` (não importa as demais).
`CHAMADOS CONTROLE.xlsx`: histórico nas abas `Casos Ant.` e meses, opcionalmente. Essa é uma fonte adicional; não faz parte da regra de exclusão de abas dos outros dois arquivos.
O carregamento de XLSX requer internet para obter a biblioteca SheetJS. Nenhum upload é enviado pelo protótipo a um servidor. Por padrão nenhum dado pessoal é distribuído junto com o protótipo: você escolhe importar os arquivos. Importações são armazenadas via `localStorage` do navegador e podem ser perdidas se limpar os dados locais. Faça backup com Exportar CSV.
Limitações e próximos passos
Não há Supabase criado ou conectado, conforme solicitado. Integração e modelo de dados serão implementados quando houver um projeto Supabase novo.
O Zendesk dos prints é o Help Center da Amazon; os botões de ticket apenas abrem uma página correspondente no navegador. Consultas automatizadas, criação de tickets, webhooks e acesso à API dependem da autorização da Amazon e não estão implementados.
Google Forms: importação por XLSX funciona, mas sincronização em tempo real ainda exige backend, permissões e configuração.
O protótipo não envia mensagens para Amazon nem WhatsApp; há apenas link para conversa.
Para não unir tickets diferentes do mesmo seller, não há junção automática entre planilhas. Uma etapa de conciliação assistida será necessária.
A cobrança de 5 dias só aparece quando a data da última resposta da Amazon é cadastrada manualmente; as planilhas não comprovam essa data.
O status é normalizado em: Aguardando Amazon, Pendente Seller, Resolvido, Desistência Seller. Conferir individualmente casos ambíguos.
Data e CNPJ/telefone em formato numérico científico em XLSX podem estar truncados no arquivo de origem. É proibido reconstruir números e identificadores por suposição.
Para produção: autenticação de 4 administradores com papéis, logs imutáveis, RLS, backups, rotinas de sincronização, deduplicação, armazenamento de anexos seguro e conformidade LGPD.
Estrutura prevista para futuro backend (não criada)
`users`, `sellers`, `cases`, `case_external_tickets`, `case_events`, `case_documents`, `form_submissions`, `automation_tasks`, `integration_sync_logs`.
Todos os dados exibidos e alterados nesta versão permanecem somente no navegador. Evitar dispositivos compartilhados.
