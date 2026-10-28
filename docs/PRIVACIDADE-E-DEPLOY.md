# Antes de publicar

- GitHub Pages publica o frontend e pode ficar acessível publicamente, mesmo com repositório privado.
- Nunca envie dados reais de sellers, prints, planilhas, senhas, service_role, secret keys ou arquivos .env ao Git.
- A publishable key no frontend é pública por design; a segurança depende de RLS e da checagem de autorização pelas Edge Functions.
- Restringir CORS das Edge Functions ao domínio de publicação e localhost nos testes.
- Antes de produção, revisar RLS, limite de requisições, recuperação de senha e fluxo da troca obrigatória de senha.
- Atenção: esta é uma versão de TESTES, não homologada para operação com dados reais.
