# Central Seller Pro — v0.20 (somente testes)

## O que mudou
- **Pessoas e lojas:** sem listagem inicial; somente resultados com pesquisa de pelo menos dois caracteres.
- **Adicionar loja:** busca de pessoa por nome, e-mail ou telefone com escolha explícita. O campo esconde o UUID da pessoa.
- **Reuniões Amazon:** busca por MCID completo, seleção de casos encontrados e inclusão na pauta. Exportação `.txt` de todos os IDs de tickets únicos dos casos marcados (um ID por linha).
- **Tratativas:** vinculação automática ao ticket mais recente do caso. A data usada para identificar o último ticket é `criado_em`.
- **Funcionários:** tabela de funcionários e redefinição de senha temporária feita SOMENTE por ADM via Edge Function.
- **Esqueci minha senha:** recuperação por e-mail através do Supabase Auth, com tela de nova senha no retorno do link.
- **Aguardando Amazon:** abertura da seta circular posicionada no canto superior direito.

## Instalação no projeto Supabase de TESTES
1. Execute `supabase/migrations/010_permissoes_admin_testes.sql` no SQL Editor de TESTES.
2. Vá em Edge Functions > Deploy a new function > Via Editor.
3. Dê o nome exato `gerenciar-funcionarios` e cole o conteúdo de `supabase/functions/gerenciar-funcionarios/index.ts` no `index.ts` do editor.
4. Publique a função. Desative **Verify JWT with legacy secret** apenas nesta função; o código valida JWT e perfil ADM por conta própria.
5. Se o site de testes usar uma origem diferente de `http://localhost:5500`, `http://127.0.0.1:5500` ou `https://gustavosellerpro.github.io`, configure o secret `ALLOWED_ORIGINS` com as origens confiáveis separadas por vírgula. Localhost e 127.0.0.1 aceitam qualquer porta.
6. Em Authentication > URL Configuration, adicione a URL exata do site de TESTES e da sua versão local ao campo **Redirect URLs** (exemplo `http://127.0.0.1:5500/index.html`).
7. Configure envio de e-mail do Supabase Auth (template de recuperação e, quando necessário, servidor SMTP adequado). A recuperação depende do envio real da mensagem.
8. Publique o frontend na branch `dev`; teste com usuários e MCIDs fictícios antes de cogitar produção.

## Sobre a mensagem "email não encontrado"
No fluxo público de recuperação, o sistema mostra sempre: **"Se o e-mail estiver cadastrado, você receberá instruções para redefinir a senha."**
Confirmar se uma conta existe permitiria descobrir endereços de funcionários. Para consultas administrativas, use a tabela de funcionários restrita ao ADM.

## Segurança e limites
- O reset administrativo altera a senha e marca `precisa_trocar_senha=true`. As políticas RLS devem continuar bloqueando usuários que ainda precisam trocar senha.
- Tokens JWT emitidos anteriormente podem permanecer válidos até expirar. Considere encerrar sessões de outros dispositivos em casos de comprometimento.
- A listagem e o reset de funcionários não funcionam antes da Edge Function estar publicada.
- O botão de TXT exporta apenas tickets já vinculados a casos marcados para reunião; a ordem segue a ordem atual dos casos no frontend.
- Nenhum SQL foi executado automaticamente e nenhum arquivo foi enviado ao GitHub.
