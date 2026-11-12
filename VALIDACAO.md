# Validação da v0.7

- [ ] Abri o projeto `qpczaqrnxjncetotuhwl` no Supabase, não o de produção.
- [ ] Confirmei as tabelas `sellers`, `lojas_amazon`, `chamados`, `tickets_zendesk`, `tratativas`, `anexos_chamados` e `categorias_amazon`.
- [ ] Executei `007_resumo_opcional.sql` no ambiente de testes.
- [ ] Consegui autenticar um usuário ativo com `precisa_trocar_senha = false`.
- [ ] Confirmei a pessoa com duas lojas de teste e MCIDs distintos.
- [ ] Visualizei o caso e o ticket inicial com o vínculo de reabertura.
- [ ] Criei e editei um caso, sem tocar na produção.
- [ ] Criei um segundo ticket vinculado ao anterior.
- [ ] Registrei uma tratativa manual com origem Amazon.
- [ ] Adicionei um link de documento com permissão restrita.
- [ ] Testei busca, filtros, tema claro/escuro e menu lateral.
- [ ] Se houver erros, salvei somente a mensagem (sem credenciais).

## Categorias v0.8
- [ ] Novo caso: selecionar Conta / Registro > Conta bloqueada > um terceiro nível.
- [ ] Trocar a categoria principal limpa os campos inferiores.
- [ ] Selecionar categoria sem subcategoria desabilita os níveis restantes.
- [ ] Salvar e reabrir o caso preserva a hierarquia selecionada.
- [ ] Confirmar que `chamados.categoria_id` contém o ID do nível mais específico.
