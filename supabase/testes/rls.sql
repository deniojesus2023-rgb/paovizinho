-- Testes de RLS e regras do pedido. Rode após migrations + seed:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/testes/rls.sql
-- Tudo roda numa transação e é desfeito no final.
begin;

create or replace function pg_temp.como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create or replace function pg_temp.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'FALHOU: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;

create or replace function pg_temp.deve_falhar(sql text, msg text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    raise notice 'ok: % (%)', msg, sqlerrm;
    return;
  end;
  raise exception 'FALHOU (deveria ter sido bloqueado): %', msg;
end $$;

-- Bloqueado = erro OU nenhuma linha afetada (a RLS filtra em silêncio).
create or replace function pg_temp.bloqueado(sql text, msg text) returns void language plpgsql as $$
declare n integer;
begin
  begin
    execute sql;
    get diagnostics n = row_count;
  exception when others then
    raise notice 'ok: % (%)', msg, sqlerrm;
    return;
  end;
  if n > 0 then raise exception 'FALHOU (% linha(s) alterada(s)): %', n, msg; end if;
  raise notice 'ok: % (0 linhas)', msg;
end $$;

grant execute on all functions in schema pg_temp to authenticated;

-- Usuários do Auth (como o login por OTP criaria)
insert into auth.users (id, phone) values
  ('aaaaaaaa-0000-4000-8000-000000000001', '5511987654321'), -- Marina (cliente)
  ('aaaaaaaa-0000-4000-8000-000000000002', '5511911112222'), -- Outro cliente
  ('aaaaaaaa-0000-4000-8000-000000000003', '5511900000001'), -- Dono (seed)
  ('aaaaaaaa-0000-4000-8000-000000000004', '5511900000002'), -- Cida, balcão JF (seed)
  ('aaaaaaaa-0000-4000-8000-000000000005', '5511933334444'); -- Entregador JF

select pg_temp.check((select auth_user_id from funcionarios where telefone = '5511900000002')
                     = 'aaaaaaaa-0000-4000-8000-000000000004', 'login vincula funcionário pelo telefone');

-- Entregador cadastrado depois do login: vínculo ao atualizar phone
insert into funcionarios (nome, telefone, funcao, unidade_id)
values ('Zé', '5511933334444', 'entrega', '11111111-1111-4111-8111-000000000001');
update auth.users set phone = phone where id = 'aaaaaaaa-0000-4000-8000-000000000005';

-- ---------- Cadastro ----------
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000001');
select completar_cadastro('Marina', '11111111-1111-4111-8111-000000000001', 'b', '52', 'portaria 2');
select pg_temp.check((select count(*) from clientes) = 1, 'cliente vê só o próprio cadastro');
select pg_temp.check((select telefone from clientes) = '5511987654321', 'telefone vem do Auth');
select pg_temp.check((select bloco from enderecos where principal) = 'B', 'endereço principal criado');
select pg_temp.check((meu_perfil()->'cliente'->>'nome') = 'Marina', 'meu_perfil retorna o cliente');
select pg_temp.deve_falhar($$update clientes set telefone = '5511000000000'$$, 'cliente não troca telefone');
select pg_temp.deve_falhar($$select definir_recebendo_pedidos('11111111-1111-4111-8111-000000000001', false)$$, 'cliente não pausa a loja');
select pg_temp.bloqueado($$update produtos set preco = 0.01 where slug = 'frances'$$, 'cliente não altera preço');
select pg_temp.bloqueado($$update unidades set taxa_entrega = 0$$, 'cliente não altera unidade');
select pg_temp.bloqueado($$insert into pedidos (cliente_id, unidade_id, tipo, pagamento) select id, '11111111-1111-4111-8111-000000000001', 'retirada', 'pix' from clientes$$, 'cliente não insere pedido direto (só via RPC)');
reset role;

select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000002');
select completar_cadastro('Outro', '11111111-1111-4111-8111-000000000002', 'F', '11');
reset role;

-- Pedido criado pelo servidor (o RPC de checkout vem no passo 2)
insert into pedidos (id, cliente_id, unidade_id, endereco_id, tipo, pagamento, subtotal, taxa, total)
select 'bbbbbbbb-0000-4000-8000-000000000001', c.id, e.unidade_id, e.id, 'entrega', 'pix', 13.40, 2.00, 15.40
  from clientes c join enderecos e on e.cliente_id = c.id where c.telefone = '5511987654321';
insert into itens_pedido (pedido_id, produto_id, quantidade, preco_unit, ponto)
select 'bbbbbbbb-0000-4000-8000-000000000001', id, q, preco, pt
  from (select p.id, p.preco, case p.slug when 'frances' then 6 else 1 end q,
               case p.slug when 'frances' then 'moreninho'::ponto_pao end pt
          from produtos p where slug in ('frances', 'cenoura')) x;

-- ---------- Visibilidade ----------
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000002');
select pg_temp.check((select count(*) from pedidos) = 0, 'outro cliente não vê o pedido da Marina');
select pg_temp.check((select count(*) from itens_pedido) = 0, 'outro cliente não vê os itens');
select pg_temp.check((select count(*) from clientes) = 1, 'outro cliente só vê a si mesmo');
reset role;

set local role anon;
select pg_temp.check((select count(*) from clientes) = 0, 'anônimo não vê clientes');
select pg_temp.check((select count(*) from produtos) = 8, 'anônimo vê o cardápio');
select pg_temp.check((select count(*) from unidades) = 3, 'anônimo vê as unidades');
reset role;

select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000001');
select pg_temp.check((select count(*) from pedidos) = 1, 'Marina vê o próprio pedido');
select pg_temp.bloqueado($$update pedidos set status = 'separando'$$, 'cliente não muda status');
reset role;

-- Entregador não vê pedido novo
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000005');
select pg_temp.check((select count(*) from pedidos) = 0, 'entrega não vê pedido novo');
reset role;

-- ---------- Balcão ----------
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000004');
select pg_temp.check((select count(*) from pedidos) = 1, 'balcão vê o pedido da unidade');
select pg_temp.check((select count(*) from clientes) = 1, 'balcão vê só clientes da unidade');
select pg_temp.deve_falhar($$update pedidos set status = 'pronto'$$, 'não pula de novo para pronto');
select pg_temp.deve_falhar($$update pedidos set total = 1$$, 'balcão não altera o total');
select pg_temp.deve_falhar($$update pedidos set pago = true$$, 'balcão não marca Pix como pago');
select pg_temp.deve_falhar($$update itens_pedido set separado = true$$, 'não marca itens antes de aceitar');
update pedidos set status = 'separando';
select pg_temp.check((select aceito_em is not null and funcionario_id is not null from pedidos), 'aceite carimba hora e funcionário');
update itens_pedido set separado = true
 where produto_id = (select id from produtos where slug = 'frances');
select pg_temp.deve_falhar($$update pedidos set status = 'pronto'$$, 'pronto bloqueado com item pendente');
update itens_pedido set em_falta = true
 where produto_id = (select id from produtos where slug = 'cenoura');
select pg_temp.check((select subtotal = 5.40 and total = 7.40 from pedidos), 'item em falta sai do total');
update pedidos set status = 'pronto';
select definir_recebendo_pedidos('11111111-1111-4111-8111-000000000001', false);
select pg_temp.check((select not aberta from unidades where nome = 'Jardim das Flores'), 'balcão pausa a unidade');
select pg_temp.deve_falhar($$select definir_recebendo_pedidos('11111111-1111-4111-8111-000000000002', false)$$, 'balcão não pausa outra unidade');
select pg_temp.bloqueado($$insert into funcionarios (nome, telefone, funcao, unidade_id) values ('X', '5511955556666', 'balcao', '11111111-1111-4111-8111-000000000001')$$, 'balcão não cadastra equipe');
select pg_temp.bloqueado($$update funcionarios set funcao = 'dono' where telefone = '5511900000002'$$, 'balcão não se promove');
reset role;

-- ---------- Entrega ----------
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000005');
select pg_temp.check((select count(*) from pedidos) = 1, 'entrega vê pedido pronto');
update pedidos set status = 'a_caminho';
update pedidos set status = 'entregue';
select pg_temp.check((select count(*) from pedidos) = 0, 'entregue some da lista do entregador');
reset role;

select pg_temp.check((select array_agg(status::text order by id) from eventos_pedido)
                     = '{novo,separando,pronto,a_caminho,entregue}', 'histórico de status completo');

-- ---------- Dono ----------
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000003');
select pg_temp.check((select count(*) from clientes) = 2, 'dono vê todos os clientes');
select pg_temp.check((select count(*) from pedidos) = 1, 'dono vê todos os pedidos');
insert into funcionarios (nome, telefone, funcao, unidade_id)
values ('Gerente VV', '5511977778888', 'gerente', '11111111-1111-4111-8111-000000000002');
select pg_temp.bloqueado($$update funcionarios set auth_user_id = 'aaaaaaaa-0000-4000-8000-000000000001' where telefone = '5511977778888'$$, 'vínculo com o Auth não muda pela API');
update produtos set preco = 0.95 where slug = 'frances';
select pg_temp.check((select preco from produtos where slug = 'frances') = 0.95, 'dono altera preço');
reset role;

-- ---------- Gerente ----------
insert into auth.users (id, phone) values ('aaaaaaaa-0000-4000-8000-000000000006', '5511977778888');
select pg_temp.como('aaaaaaaa-0000-4000-8000-000000000006');
select pg_temp.check((select count(*) from pedidos) = 0, 'gerente de outra unidade não vê o pedido');
select pg_temp.check((select count(*) from clientes) = 1, 'gerente vê clientes da própria unidade');
insert into funcionarios (nome, telefone, funcao, unidade_id)
values ('Balcão VV', '5511944445555', 'balcao', '11111111-1111-4111-8111-000000000002');
select pg_temp.deve_falhar($$insert into funcionarios (nome, telefone, funcao, unidade_id) values ('G2', '5511966667777', 'gerente', '11111111-1111-4111-8111-000000000002')$$, 'gerente não cria gerente');
select pg_temp.deve_falhar($$insert into funcionarios (nome, telefone, funcao, unidade_id) values ('B2', '5511966667778', 'balcao', '11111111-1111-4111-8111-000000000001')$$, 'gerente não cria equipe em outra unidade');
select pg_temp.bloqueado($$update unidades set taxa_entrega = 3 where nome = 'Jardim das Flores'$$, 'gerente não edita outra unidade');
update unidades set taxa_entrega = 2.50 where nome = 'Vila Verde';
select pg_temp.check((select taxa_entrega from unidades where nome = 'Vila Verde') = 2.50, 'gerente edita a própria unidade');
reset role;

select 'todos os testes passaram' as resultado;
rollback;
