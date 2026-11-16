# Seller Pro — v0.14: logos unificadas

Base: v0.13 validada. Alterações exclusivamente de identidade visual:

- Login e troca de senha: agora exibem o logo horizontal **Seller Pro CHAMADOS** (`assets/logo-chamados-aberto.png`).
- Menu expandido: permanece com o mesmo logo horizontal, com dimensões e seta da v0.13.
- Menu recolhido: permanece com `assets/logo-chamados-fechado.png`.
- Favicon: usa a marca SP CHAMADOS compacta.
- `logo.png` na raiz foi substituído pela versão horizontal atual, para evitar resíduos de identidade antiga.
- CSS do logo do login redimensionado para 290px de largura máxima, responsivo.

## Publicação

Envie o conteúdo da pasta para a branch `dev`, mantendo `index.html` na raiz; commit sugerido: `fix: unificar logos de login e menu v014`.
Nenhuma alteração SQL, de Supabase ou Edge Functions é necessária.
Teste login, troca de senha e recolhimento do menu. Em caso de cache antigo, use Ctrl+F5.
