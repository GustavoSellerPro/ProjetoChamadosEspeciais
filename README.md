# Seller Pro — Dashboard conectado ao Supabase (v0.2)

Substitua **todos os arquivos** na raiz do repositório GitHub Pages pelos arquivos deste ZIP, preservando as pastas. Commit sugerido: `feat: dashboard de chamados com filtros Supabase`.

## O que funciona
- Login e primeiro acesso existentes, sem remover administração de funcionários.
- Dashboard em modo **somente leitura**: total, não resolvidos, aguardando Amazon, pendente seller, resolvidos, concluídos.
- Filtros de mês de abertura, status e pesquisa por título/ID; tabela com tempo decorrido e marcação para reunião.
- Atualizar dados do Supabase. Nenhum dado fictício é exibido. Banco vazio mostra zeros.

## Antes de compartilhar com a equipe
- Não inserir dados pessoais reais enquanto não terminar revisão de segurança de RLS, privilégios das tabelas, Storage, recuperação de senha e auditoria.
- Esta versão **não** cria chamados e **não** importa formulários ou planilhas.
- Para usuários com senha temporária ainda não trocada, a aplicação deve impedir o acesso ao dashboard.
- Os indicadores representam os casos **já cadastrados na tabela `chamados`**, não as planilhas ainda não importadas.
- O status `Concluido` foi mantido conforme o SQL inicial. A regra de negócio será refinada antes da importação.
- O Pages é público; somente o frontend fica hospedado nele, e a proteção real dos dados depende do Supabase.

## Teste
1. Publicar na branch `main` do GitHub.
2. Fazer login como administrador.
3. Confirmar que dashboard vazio mostra números zero, não inventados.
4. Clicar em Atualizar dados e verificar ausência de erros no navegador.
5. Testar login de usuário comum e o bloqueio de conta ainda sem troca de senha.

O código ainda é uma versão inicial e precisa de testes de segurança antes da utilização real.
