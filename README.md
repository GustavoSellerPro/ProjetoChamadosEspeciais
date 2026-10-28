# Central de Chamados — v0.5

Atualização sobre a v0.4. Interface para desktop/mobile, dashboard com cores, menu recolhível, perfil por avatar e cadastro único de sellers vinculado a vários chamados.

## Instalar
1. No **SQL Editor** do Supabase, execute `supabase/migrations/004-seller-case-sync.sql` uma vez. Ele cria trigger de atualização e índices. Não apaga registros.
2. Substitua os arquivos do GitHub Pages pelo conteúdo deste ZIP e faça commit `feat: entidades sellers e dashboard desktop v05`.
3. Teste com contas e dados fictícios: abrir seller, editar seus dados, visualizar vários chamados, recolher menu, avatar, ordenação e responsividade.

## Importante
- O relacionamento 1:N já existe no banco (`sellers` → `chamados.seller_id`).
- A edição do cadastro centralizado do seller está disponível para usuários autenticados **ativos** conforme suas políticas RLS. Nenhum dado pessoal deve ser enviado ao repositório.
- **Google Forms não está sincronizado ainda.** A integração automática exige configurar Apps Script / endpoint seguro e validação de duplicações. O formulário não é importado automaticamente nesta versão.
- A ordenação usa `chamados.atualizado_em`; neste momento registra edições manuais dos chamados. Quando a API Zendesk ou o fluxo de mensagens estiver integrado, atualizaremos essa data pelos eventos relevantes.
- `email`, `telefone`, `mcid` e `cnpj` continuam na tabela `sellers`; RLS deve ser auditado antes de produção. 
- Não há exclusão de sellers nem de chamados nesta versão.
