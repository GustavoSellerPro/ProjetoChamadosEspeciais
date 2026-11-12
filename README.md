# Seller Pro — Central de Chamados v0.8 (AMBIENTE DE TESTES)

**Este pacote se conecta EXCLUSIVAMENTE ao Supabase de testes** `qpczaqrnxjncetotuhwl.supabase.co`.

Não modifica nem se conecta ao banco de produção `sshhyqywxwpijsosxdvz.supabase.co`. Nenhum deploy ou commit foi realizado automaticamente.

## Atualização v0.8 — Categorias em cascata

- Ao cadastrar ou editar um caso, categoria, subcategoria e subsubcategoria ficam em **três seletores dependentes**.
- As opções são carregadas diretamente da tabela `categorias_amazon` e seus relacionamentos `parent_id`.
- Subcategoria e terceiro nível são desativados quando não se aplicam.
- Na edição, os três níveis previamente salvos são restaurados.
- Apenas o ID do nível mais específico é gravado no campo `chamados.categoria_id`.
- **Nenhum SQL adicional é necessário**. Nenhuma Edge Function foi alterada.

## O que está implementado

- Login via Supabase Auth e leitura de `usuarios` para confirmar status e cargo.
- Tela de primeira troca de senha (exige publicar a função `definir-senha` no ambiente de testes).
- Painel de cadastro administrativo (exige publicar a função `criar-funcionario` no ambiente de testes).
- Dashboard com métricas e tabela ordenada por `atualizado_em`.
- Pessoa (`sellers`) com várias lojas Amazon (`lojas_amazon`), cada uma por MCID.
- Cadastro/edição de pessoa, loja e caso (entidade `chamados`).
- Cadastro de novo ticket Zendesk com vínculo opcional ao anterior, preservando o ticket antigo.
- Histórico de tratativas **manual**, com origem Amazon ou Seller Pro.
- Links HTTPS de documentos, inclusive múltiplos links do Drive separados por vírgula.
- Acesso rápido à planilha externa, temas claro/escuro e menu recolhível.
- Dados só são carregados após login e não são armazenados no `localStorage` (apenas preferência de tema).

## Ordem de instalação

1. **Confirme** que está no projeto Supabase **TESTES** e que os scripts SQL 01 a 06 foram executados sem erros, incluindo a conta ADM.
2. No SQL Editor **do ambiente de testes**, execute `supabase/migrations/007_resumo_opcional.sql` para habilitar o resumo editável independente da descrição. Apesar do nome, esta etapa é necessária **para salvar o resumo editável**; faça backup antes, e não rode em produção.
3. **Não substitua `main`** do GitHub. Crie/use uma branch `dev` ou um repositório de teste separado e coloque os arquivos deste ZIP na raiz.
4. Teste em `http://localhost:8000/` com `python -m http.server 8000`, dentro da pasta extraída. Configure o endereço local nas Redirect URLs do Supabase quando for usar fluxos de e-mail.
5. Faça login com o **usuário ADMIN criado no Supabase de testes**. Não use as credenciais da produção.
6. Teste em sequência: consultar seller fictício -> consultar lojas -> abrir caso -> criar ticket de teste vinculado ao anterior -> registrar tratativa -> adicionar link HTTPS fictício.
7. Se optar por GitHub Pages, configure a publicação em destino **separado** da página de produção; a branch `dev` sozinha **não** cria automaticamente um Pages separado.

## Recursos que dependem de configuração adicional

- `criar-funcionario` e `definir-senha` são Edge Functions de **cada projeto** Supabase. As publicadas na produção não existem automaticamente no teste. A aplicação mostra erro claro caso ainda não estejam implantadas.
- Ainda **não há** integração automática com Google Forms ou Zendesk nesta versão.
- Anexos são apenas referências HTTPS, não uploads privados nem download em lote; o Drive exige permissão própria para acessar arquivos.
- O cadastro de seller e a criação de caso/ticket são operações separadas. Não utilizar com dados reais até implementar transações server-side e revisar segurança, permissões e auditoria.
- Não é sistema multiempresa. Todos os usuários ativos do teste poderão trabalhar com as fichas de acordo com as políticas RLS do banco.
- A interface requer internet para carregar a biblioteca `supabase-js` pelo CDN.

## Diagnóstico rápido

- **"Falha ao consultar o banco"**: verificar tabelas, GRANTs, RLS e usuário ativo no projeto de teste. A aplicação não desativa as proteções.
- **"Column 'resumo' not found"**: executar migração 007 no banco de testes.
- **"Function not found" ao cadastrar funcionário/trocar senha**: configurar a respectiva Edge Function no projeto de testes.
- **Nenhum ticket aparece**: confirme se os dados fictícios foram inseridos na tabela `tickets_zendesk` e o usuário tem `SELECT`.
- **GitHub Pages mostra versão antiga**: confira branch, pasta de publicação e cache do navegador.

## Segurança

A publishable key no `js/config.js` é pública por definição. **Nunca colocar** senha do banco, secret key, service_role, token de sessão ou segredo do Forms no GitHub. Os controles reais são RLS + permissões + funções com validação no servidor. Para operar com dados reais, utilize hospedagem e controles de acesso aprovados pela empresa.

## Commit sugerido

`feat: selecao hierarquica de categorias amazon v08`


## Atualização v0.9 — campos condicionais e tema claro

- As listas **Subcategoria** e **Subsubcategoria** só aparecem quando existem filhos cadastrados na tabela `categorias_amazon`.
- Ao mudar a categoria, os níveis inferiores são limpos automaticamente.
- Ao editar um caso, a hierarquia salva é restaurada.
- O tema claro agora possui fundo cinza médio, superfícies diferenciadas, menu grafite e maior contraste.
- Nenhuma migração SQL é necessária. O frontend continua apontando exclusivamente para o Supabase de **testes**.

**Publicação:** substituir os arquivos na branch `dev` e testar no ambiente de desenvolvimento; não publicar na `main` antes de validar.
