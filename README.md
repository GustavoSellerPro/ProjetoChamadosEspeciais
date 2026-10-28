# Central de Chamados Especiais — Seller Pro v0.3

## Atualização
- Layout desktop-first, com barra lateral e tabela ampla, responsivo para tablets e celulares.
- Status consolidados: Aguardando Amazon, Pendente Seller e Finalizado.
- Preserva autenticação, cadastro de funcionários e troca de senha da versão anterior.
- Dashboard somente leitura.

## Ordem de instalação
1. Faça backup dos dados do Supabase antes da migração.
2. Execute `supabase/migrations/003-status-unificado.sql` no SQL Editor. Este arquivo altera a regra de status e converte os registros antigos.
3. Envie os arquivos do ZIP para a raiz do repositório GitHub Pages, substituindo os antigos.
4. Commit sugerido: `feat: dashboard responsivo e status unificados`.
5. Teste login ADM/Usuário, navegação, tema, filtros e celular.

## Segurança
O GitHub Pages é público. Não inclua segredos, arquivos de sellers ou tokens privados no repositório. A chave publishable é pública; segurança depende de RLS e das funções de backend. Não use dados pessoais reais até validar as políticas.
