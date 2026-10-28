# Seller Pro — Central de Chamados Especiais

Versão de **testes** do frontend estático, conectada ao Supabase existente.
Este pacote contém a versão validada de **login + administração de usuários + primeiro acesso**, ainda **não** o dashboard compartilhado de chamados.

## Arquivos
- `index.html`: entrada do GitHub Pages
- `css/style.css`: estilos claros e escuros
- `js/app.js`: interface e integração com Supabase
- `logo.png`: logo enviada
- `.nojekyll`: desativa o processamento Jekyll do Pages
- `supabase/functions/definir-senha/index.ts`: cópia do código anteriormente usado
- `supabase/functions/criar-funcionario/README.md`: instruções para recuperar o código real da função publicada (não temos snapshot validado)
- `supabase/migrations/`: histórico parcial; NÃO rodar novamente sem revisar

## Publicar no GitHub Pages
1. Criar repositório `sellerpro-central-chamados`.
2. Enviar o conteúdo desta pasta para a raiz da branch `main` (o `index.html` precisa estar na raiz).
3. GitHub → Settings → Pages → Deploy from a branch → `main` → `/(root)` → Save.
4. Acessar `https://SEU-USUARIO.github.io/sellerpro-central-chamados/`.
5. No Supabase → Authentication → URL Configuration, adicionar a URL publicada aos Redirect URLs necessários para recuperação de senha.
6. Testar login, criação de conta fictícia e troca obrigatória de senha SEM dados reais.

## Desenvolvimento local
Na pasta, usar VS Code Live Server ou `python -m http.server 8000`, e acessar http://localhost:8000.

## Importante
- Nunca versionar credenciais secretas. A publishable key no JS é pública.
- O Pages é hospedagem estática; funções são executadas no Supabase.
- Ainda falta auditoria de segurança, tratamento completo de recuperação de senha, migrações fielmente versionadas e integração de tickets ao Supabase.
- Veja `docs/PRIVACIDADE-E-DEPLOY.md`.
