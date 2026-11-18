# Seller Pro — v0.24 · Fluxo completo dentro da conferência de Forms

## Atualização

O formulário novo permite fazer tudo **dentro de um único pop-up**:

1. **Pessoa:** cadastrar seller ou escolher pessoa já existente (funcionalidade da v0.23).
2. **Loja:** criar ou escolher loja da mesma pessoa (funcionalidade da v0.23). Se não houver MCID, o CNPJ com 14 dígitos é obrigatório. No banco, MCID permanece `NULL` (XXX só na interface).
3. **Caso:** cadastrar caso da pessoa/loja, usando o título, resumo e descrição do Forms como sugestões editáveis. É possível escolher categoria, status, observações internas, reunião Amazon e números de tickets Zendesk já existentes. Alternativamente, escolher um caso **já registrado para aquela mesma loja** para não duplicar.
4. **Finalização automática:** ao salvar o caso novo ou confirmar o existente, o banco vincula `entradas_forms.chamado_id` e altera seu `status` para `processado` **na mesma transação**. Não é necessário voltar ao formulário, buscar ID nem clicar em outro botão.

As **respostas originais** agora ficam acessíveis por um bloco recolhível no final, para reduzir a poluição da tela.

### Importante sobre tickets

- O campo de tickets é **opcional** e aceita números separados por `,`, `/`, `;` ou espaços; ele registra vínculos locais em `tickets_zendesk`. **Não abre tickets no Zendesk/Amazon.**
- Não insira IDs já vinculados a outro caso. Nesse cenário, o sistema recusa a transação sem criar caso nem processar o formulário; revise os dados ou utilize a opção de selecionar caso já existente.
- Ao **selecionar caso existente**, os campos de novo caso/tickets são ocultos. Faça alterações/tickets depois na ficha daquele caso, se necessário.
- Abertura/gerenciamento de tratativas e anexos continua na ficha do caso. As respostas e links originais enviados no Forms permanecem preservados em `entradas_forms.respostas`.

## Instalar no Supabase de TESTES

**Projeto:** `qpczaqrnxjncetotuhwl`. **Nunca execute em produção.**

1. Confirme que as migrações anteriores `009`, `011`, `012` e `013` já foram aplicadas.
2. Faça backup se necessário e, em **Supabase → SQL Editor** do projeto de testes, execute **`supabase/migrations/014_criar_caso_e_processar_forms.sql`**.
3. O SQL devolve uma linha com nome da função e `acesso_autenticado = true`.
4. Atualize somente os arquivos do site na branch `dev` ou em Live Server local. `main` e produção não devem ser alteradas.
5. Recarregue usando Ctrl+F5, faça login e vá a **Formulários pendentes → Novas solicitações → Conferir**.
6. Se a pessoa e loja já estiverem vinculadas, o passo 3 aparecerá imediatamente. Se não, complete os passos 1 e 2 normalmente.
7. Revise o caso, deixe o seletor em **Criar novo caso** e clique **Criar caso, vincular e processar formulário**.
8. Confirme que a mesma janela informa **Formulário processado com sucesso** e permite **Abrir caso cadastrado**. O formulário deve desaparecer do filtro **Pendentes** e aparecer em **Processados**.

**Não é necessário alterar Google Apps Script, Edge Function `receber-formulario`, webhook secret ou GitHub da produção.**

## Consulta para verificar o fluxo

```sql
SELECT e.status, e.origem_tipo, e.seller_id IS NOT NULL AS tem_pessoa,
       e.loja_id IS NOT NULL AS tem_loja,
       e.chamado_id IS NOT NULL AS tem_caso,
       COUNT(*) AS total
FROM public.entradas_forms e
GROUP BY e.status,e.origem_tipo,tem_pessoa,tem_loja,tem_caso
ORDER BY e.origem_tipo,e.status;
```

## Resiliência, auditoria e segurança

- A função `public.forms_criar_caso_processar` utiliza `SECURITY INVOKER`, portanto respeita RLS e permissões do usuário autenticado e a checagem `private.usuario_ativo()`.
- Ao executar a criação, um bloqueio transacional na linha do formulário evita duas criações concorrentes. Se o formulário já estiver processado, a função devolve o mesmo caso sem duplicar.
- Se qualquer INSERT de caso/ticket ou UPDATE do formulário falhar, a **transação inteira é revertida**: o formulário continua pendente e não cria um caso parcialmente salvo.
- O vínculo com caso existente exige **mesma pessoa e mesma loja** registradas no formulário.
- A v0.24 foi verificada localmente quanto a sintaxe e fluxo simulado, **sem executar alterações remotas nem validar com sessão real**. Faça o primeiro teste em dados fictícios.
