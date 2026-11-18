# Seller Pro — Central de Chamados v0.23

## Objetivo

Na tela **Formulários pendentes > Novas solicitações > Conferir**, ao final do pop-up, o analista pode:

1. **Criar seller** (pessoa) com nome, e-mail e telefone sugeridos pelo Forms, **ou vincular pessoa existente** localizada por busca.
2. **Criar e vincular loja** à pessoa confirmada. Este botão é exibido ao lado do primeiro e só é habilitado depois do vínculo da pessoa.

**Nesta versão NÃO são criados caso interno, ticket Zendesk, tratativa, nem anexos.** A resposta do Forms continua como **pendente** até a abertura/vinculação de caso em uma etapa posterior.

## Fluxo sem MCID

- Se o Forms informar `XXX`, `N/A`, `Sem MCID` ou deixar vazio, o novo cadastro grava **MCID = NULL** na loja.
- Para criar uma loja sem MCID, é obrigatório informar um CNPJ com 14 dígitos, que pode ser editado na conferência.
- As telas identificam a ausência de MCID com **XXX · Sem MCID**; XXX é apenas um rótulo visual.
- A situação da conta pode ser preenchida como *Conta não criada*, *Criação em andamento*, *Criação bloqueada* ou *Conta ativa*; contas sem MCID não devem ser marcadas como ativas nesse fluxo.
- Quando houver MCID, o cadastro de loja poderá ser atualizado na ficha da loja existente (sem gerar nova pessoa ou caso).

## Antiduplicidade

- Se encontrar pessoa com mesmo e-mail ou telefone, o sistema pede que o analista selecione o cadastro existente.
- Mostra pessoas vinculadas a MCID/CNPJ encontrados para conferência, **sem fazer associação automática com base apenas no CNPJ**.
- Se encontrar loja com o mesmo MCID, vincula a existente se pertencer à pessoa selecionada; não mistura lojas de pessoas diferentes.
- Para reutilizar loja identificada somente pelo CNPJ, selecione a loja existente. Não cria nova loja provisória sobre CNPJ já registrado.
- O vínculo pessoa/loja fica gravado em `entradas_forms`, permitindo retomar o cadastro ao reabrir o formulário.
- Cada botão usa **uma função transacional do PostgreSQL** (`SECURITY INVOKER`, RLS mantida), evitando criação parcial dentro de cada etapa.

## Atualização (apenas ambiente de TESTES)

1. Confirme que já executou as migrações `009_fila_forms_testes.sql` e `011_separar_formularios_historico_novo.sql` no projeto `qpczaqrnxjncetotuhwl`.
2. No **SQL Editor** do Supabase de testes, execute **`supabase/migrations/012_cadastro_assistido_forms.sql`** uma única vez.
3. Substitua os arquivos do site da branch `dev` pelos arquivos do ZIP da v0.23. A publicação da branch `dev` e o GitHub Pages em `main` são processos diferentes; valide no Live Server ou em uma publicação de testes.
4. Pressione **Ctrl+F5** e entre com um usuário ativo no ambiente de testes.
5. Encontre um formulário novo na fila e abra **Conferir**.
6. Revise nome, e-mail e telefone; **Criar seller** ou selecione uma pessoa existente e clique **Vincular pessoa existente**.
7. O botão ao lado será liberado: revise MCID, CNPJ, nome da loja, e-mail Amazon e situação da conta; clique **Criar e vincular loja**.
8. Feche e reabra o pop-up. Ele deverá mostrar os dois vínculos preservados.

**Não precisa alterar** `Code.gs`, o webhook `receber-formulario` ou `FORMS_WEBHOOK_SECRET`, pois a integração do Forms já está funcionando.

## Verificação no Supabase (sem dados pessoais)

```sql
select count(*) as forms_com_pessoa from public.entradas_forms where seller_id is not null;
select count(*) as forms_com_loja from public.entradas_forms where loja_id is not null;
select count(*) as lojas_sem_mcid from public.lojas_amazon where nullif(btrim(mcid),'') is null;
```

## Limitações e validação

- Este pacote foi verificado por análise estática e testes de extração dos campos (incluindo MCID `XXX`), mas **não foi aplicado ou testado com uma sessão real** no Supabase de testes.
- CNPJ é conferido quanto a **14 dígitos**, não foi implementada validação de dígitos verificadores. Verifique o documento do seller antes de confirmar.
- Os cadastros continuam sujeitos às políticas RLS e às permissões já definidas na base.
- Não execute esta migração no Supabase de produção. Faça backup e valide os dois botões no ambiente de testes antes de publicar.
