# Seller Pro Central de Chamados — v0.19

Esta entrega reúne o projeto completo da v0.15 e os refinamentos de ícones da v0.18.

## Alterações v0.19

- **Aguardando Amazon**: seta ao final de um arco circular de 288° (80% do círculo), com direção horária correta. Ao passar o mouse, o ícone inteiro gira em sentido horário.
- **Dashboard mais compacto**: indicadores em uma linha em monitores largos; 3/2 em telas médias; 2 colunas ou 1 em telas pequenas.
- **Pop-up de indicadores em lista**: MCID/Loja, ticket clicável, status, resumo, data da última atualização e botão Detalhes.
- **Finalizados**: giro horizontal e pulo com duração reduzida para 0,48 s.

## Instalação

1. Extraia o ZIP.
2. Abra a pasta `sellerpro-central-v019-dashboard-compacto`.
3. Execute `index.html` no Live Server.
4. Depois de conferir tudo, envie o conteúdo da pasta para a branch `dev` no GitHub.
5. Faça `Ctrl + F5` para atualizar o cache do navegador.

**Nenhuma migração SQL ou alteração no Supabase é necessária.** O projeto permanece apontando exclusivamente para o Supabase de testes.

Commit sugerido: `style: compactar indicadores corrigir seta e listar casos v019`
