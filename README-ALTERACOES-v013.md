# Central Seller Pro — v0.13, correção do menu

Base: v0.12, que por sua vez preserva a navegação e os recursos da v0.10.

## Alterações
- Logo completo menor (limite 168 px de largura), com proporção preservada e sem deformação.
- Menu aberto: seta para a esquerda, à direita da logo.
- Menu recolhido: logo SP centralizada (54 px), seta para a direita logo abaixo.
- Cabeçalho usa grid de duas colunas no modo expandido, corrigindo a sobreposição vista no vídeo.
- No celular, a barra lateral deslizante usa cabeçalho expandido, mesmo quando a preferência de desktop estiver recolhida.
- Preservadas páginas, dashboard, autenticação, menus, dados e Supabase de testes.

## Publicação
1. Teste localmente com Live Server, sobretudo expandir/recolher diversas vezes e mudar tema.
2. Commit na branch `dev`: `fix: corrigir escala da logo e seta do menu v013`.
3. Se o navegador exibir a versão antiga, use Ctrl+F5.

Nenhuma migração SQL ou alteração nas Edge Functions.
