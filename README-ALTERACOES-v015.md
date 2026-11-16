# v0.15 — Dashboard animado e links automáticos de ticket

## Alterações desta versão

1. **Link automático do ticket Zendesk**
   - Todo ticket agora usa automaticamente o padrão:
     `https://amazonlatam.zendesk.com/hc/pt-br/requests/{numero_do_ticket}`
   - Ao cadastrar um novo ticket, o link é gerado sozinho.
   - O campo de link fica apenas como visualização, em modo somente leitura.

2. **Tickets clicáveis**
   - Dashboard principal
   - Lista de casos e tickets
   - Reuniões Amazon
   - Modal de detalhes do caso

3. **Dashboard visual no estilo solicitado**
   - Cards maiores e mais informativos
   - Ícones animados no hover:
     - Total de chamados: planeta gira
     - Em andamento: três pontos pulam em sequência
     - Aguardando Amazon: loading gira
     - Pendente Seller: personagem acena
     - Finalizados: check dá mini pulo/giro

4. **Popup dos indicadores**
   - Ao clicar no card do dashboard, abre um popup em formato de cards
   - Cada card mostra MCID, loja/pessoa, status, resumo, tickets clicáveis e data de atualização

## Observação

Esta versão não exige SQL adicional e continua apontando para o Supabase de testes.
