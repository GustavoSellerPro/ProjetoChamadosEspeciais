# Atualização do menu — v0.12 (base v0.10)

Este pacote parte da **v0.10 original**, evitando as mudanças de navegação/estilo da v0.11.

## O que foi alterado
- `index.html`: troca do logo da barra lateral por duas imagens enviadas pelo usuário.
- `assets/logo-chamados-aberto.png`: logotipo SELLER PRO CHAMADOS.
- `assets/logo-chamados-fechado.png`: logotipo SP CHAMADOS.
- `css/style.css`: transição de logos ao abrir/recolher o menu; mantidos os demais estilos.
- `js/app.js`: atualiza título e atributos de acessibilidade do botão; mantém a lógica existente.

## Publicação
1. Envie o conteúdo deste ZIP à branch `dev`, não à `main`.
2. Faça commit `fix: usar logos oficiais na animacao do menu`.
3. Teste menu expandido, menu recolhido e dispositivo móvel.

**Sem SQL ou Edge Functions.** Mantém `js/config.js` apontando para o Supabase de testes.
