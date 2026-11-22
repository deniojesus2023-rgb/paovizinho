-- =============================================================================
-- Pão Vizinho — Row Level Security
--   Cliente: só os próprios dados.
--   Equipe: só a unidade dela (entrega: só pedidos prontos / a caminho).
--   Dono: tudo.
-- As funções private.* são chamadas via (select …) para serem avaliadas uma vez
-- por consulta, e não por linha.
-- =============================================================================

alter table public.unidades         enable row level security;
alter table public.produtos         enable row level security;
alter table public.estoque          enable row level security;
alter table public.clientes         enable row level security;
alter table public.enderecos        enable row level security;
alter table public.funcionarios     enable row level security;
alter table public.pedidos          enable row level security;
alter table public.itens_pedido     enable row level security;
alter table public.eventos_pedido   enable row level security;
alter table public.assinaturas      enable row level security;
alter table public.itens_assinatura enable row level security;
alter table public.combos           enable row level security;
alter table public.itens_combo      enable row level security;
alter table public.cupons           enable row level security;

-- ---------------------------------------------------------------------------
-- Unidades: vitrine pública (lista de condomínios, loja aberta/fechada)
-- ---------------------------------------------------------------------------
create policy "unidades: todos veem"
  on public.unidades for select to anon, authenticated
  using (true);

create policy "unidades: dono cria"
  on public.unidades for insert to authenticated
  with check ((select private.eh_dono()));

create policy "unidades: dono e gerente editam"
  on public.unidades for update to authenticated
  using (private.gerencia_unidade(id))
  with check (private.gerencia_unidade(id));

create policy "unidades: dono remove"
  on public.unidades for delete to authenticated
  using ((select private.eh_dono()));

-- ---------------------------------------------------------------------------
-- Produtos: cardápio público; só o dono edita (cardápio é da rede)
-- ---------------------------------------------------------------------------
create policy "produtos: todos veem os ativos"
  on public.produtos for select to anon, authenticated
  using (ativo or (select private.eh_funcionario()));

create policy "produtos: dono cria"
  on public.produtos for insert to authenticated
  with check ((select private.eh_dono()));

create policy "produtos: dono edita"
  on public.produtos for update to authenticated
  using ((select private.eh_dono())) with check ((select private.eh_dono()));

create policy "produtos: dono remove"
  on public.produtos for delete to authenticated
  using ((select private.eh_dono()));

-- ---------------------------------------------------------------------------
-- Estoque: disponibilidade pública; balcão, gerente e dono ajustam
-- ---------------------------------------------------------------------------
create policy "estoque: todos veem"
  on public.estoque for select to anon, authenticated
  using (true);

create policy "estoque: equipe da unidade cria"
  on public.estoque for insert to authenticated
  with check (private.opera_unidade(unidade_id));

create policy "estoque: equipe da unidade edita"
  on public.estoque for update to authenticated
  using (private.opera_unidade(unidade_id))
  with check (private.opera_unidade(unidade_id));

create policy "estoque: gerente remove"
  on public.estoque for delete to authenticated
  using (private.gerencia_unidade(unidade_id));

-- ---------------------------------------------------------------------------
-- Clientes (cadastro via RPC completar_cadastro)
-- ---------------------------------------------------------------------------
create policy "clientes: o próprio e a equipe da unidade veem"
  on public.clientes for select to authenticated
  using (auth_user_id = (select auth.uid()) or private.cliente_visivel_para_equipe(id));

create policy "clientes: o próprio edita"
  on public.clientes for update to authenticated
  using (auth_user_id = (select auth.uid()))
  with check (auth_user_id = (select auth.uid()));

create policy "clientes: dono edita"
  on public.clientes for update to authenticated
  using ((select private.eh_dono())) with check ((select private.eh_dono()));

-- Telefone e vínculo com o Auth não mudam pela API.
revoke update on public.clientes from anon, authenticated;
grant update (nome) on public.clientes to authenticated;

-- ---------------------------------------------------------------------------
-- Endereços
-- ---------------------------------------------------------------------------
create policy "enderecos: o próprio e a equipe da unidade veem"
  on public.enderecos for select to authenticated
  using (cliente_id = (select private.meu_cliente_id()) or private.acessa_unidade(unidade_id));

create policy "enderecos: o próprio cria"
  on public.enderecos for insert to authenticated
  with check (cliente_id = (select private.meu_cliente_id()));

create policy "enderecos: o próprio edita"
  on public.enderecos for update to authenticated
  using (cliente_id = (select private.meu_cliente_id()))
  with check (cliente_id = (select private.meu_cliente_id()));

create policy "enderecos: o próprio remove"
  on public.enderecos for delete to authenticated
  using (cliente_id = (select private.meu_cliente_id()));

-- ---------------------------------------------------------------------------
-- Equipe
-- ---------------------------------------------------------------------------
create policy "funcionarios: a si mesmo, colegas da unidade e o dono veem"
  on public.funcionarios for select to authenticated
  using (auth_user_id = (select auth.uid())
         or (select private.eh_dono())
         or (unidade_id is not null and private.acessa_unidade(unidade_id)));

-- Dono gerencia todos; gerente gerencia balcão e entrega da própria unidade.
create policy "funcionarios: dono e gerente cadastram"
  on public.funcionarios for insert to authenticated
  with check ((select private.eh_dono())
              or (funcao in ('balcao', 'entrega')
                  and (select private.minha_funcao()) = 'gerente'
                  and unidade_id = (select private.minha_unidade())));

create policy "funcionarios: dono e gerente editam"
  on public.funcionarios for update to authenticated
  using ((select private.eh_dono())
         or (funcao in ('balcao', 'entrega')
             and (select private.minha_funcao()) = 'gerente'
             and unidade_id = (select private.minha_unidade())))
  with check ((select private.eh_dono())
              or (funcao in ('balcao', 'entrega')
                  and (select private.minha_funcao()) = 'gerente'
                  and unidade_id = (select private.minha_unidade())));

create policy "funcionarios: dono e gerente removem"
  on public.funcionarios for delete to authenticated
  using ((select private.eh_dono())
         or (funcao in ('balcao', 'entrega')
             and (select private.minha_funcao()) = 'gerente'
             and unidade_id = (select private.minha_unidade())));

-- O vínculo com o Auth é feito só pelo trigger de login.
revoke insert, update on public.funcionarios from anon, authenticated;
grant insert (nome, telefone, funcao, unidade_id, turno, ativo) on public.funcionarios to authenticated;
grant update (nome, telefone, funcao, unidade_id, turno, ativo) on public.funcionarios to authenticated;

-- ---------------------------------------------------------------------------
-- Pedidos (criação via RPC no passo 2; aqui só leitura e avanço de status)
-- ---------------------------------------------------------------------------
create policy "pedidos: cliente vê os seus"
  on public.pedidos for select to authenticated
  using (cliente_id = (select private.meu_cliente_id()));

create policy "pedidos: equipe vê os da unidade"
  on public.pedidos for select to authenticated
  using ((select private.eh_dono())
         or (unidade_id = (select private.minha_unidade())
             and ((select private.minha_funcao()) in ('gerente', 'balcao')
                  or ((select private.minha_funcao()) = 'entrega'
                      and tipo = 'entrega' and status in ('pronto', 'a_caminho')))));

-- Regras de transição e campos permitidos: triggers validar_status_pedido e proteger_campos_pedido.
create policy "pedidos: equipe atualiza os da unidade"
  on public.pedidos for update to authenticated
  using ((select private.eh_dono())
         or (unidade_id = (select private.minha_unidade())
             and ((select private.minha_funcao()) in ('gerente', 'balcao')
                  or ((select private.minha_funcao()) = 'entrega'
                      and tipo = 'entrega' and status in ('pronto', 'a_caminho')))))
  with check ((select private.eh_dono())
              or (unidade_id = (select private.minha_unidade())
                  and (select private.minha_funcao()) in ('gerente', 'balcao', 'entrega')));

-- ---------------------------------------------------------------------------
-- Itens do pedido: visíveis junto com o pedido; balcão marca separado / em falta
-- ---------------------------------------------------------------------------
create policy "itens_pedido: visíveis com o pedido"
  on public.itens_pedido for select to authenticated
  using (exists (select 1 from public.pedidos p where p.id = pedido_id));

create policy "itens_pedido: balcão marca"
  on public.itens_pedido for update to authenticated
  using (exists (select 1 from public.pedidos p
                  where p.id = pedido_id and private.opera_unidade(p.unidade_id)))
  with check (exists (select 1 from public.pedidos p
                       where p.id = pedido_id and private.opera_unidade(p.unidade_id)));

revoke update on public.itens_pedido from anon, authenticated;
grant update (separado, em_falta) on public.itens_pedido to authenticated;

-- ---------------------------------------------------------------------------
-- Histórico de status: só leitura (escrito por trigger)
-- ---------------------------------------------------------------------------
create policy "eventos_pedido: visíveis com o pedido"
  on public.eventos_pedido for select to authenticated
  using (exists (select 1 from public.pedidos p where p.id = pedido_id));

-- ---------------------------------------------------------------------------
-- Assinaturas "Pão todo dia"
-- ---------------------------------------------------------------------------
create policy "assinaturas: cliente vê as suas, equipe as da unidade"
  on public.assinaturas for select to authenticated
  using (cliente_id = (select private.meu_cliente_id()) or private.acessa_unidade(unidade_id));

create policy "assinaturas: cliente cria a sua"
  on public.assinaturas for insert to authenticated
  with check (cliente_id = (select private.meu_cliente_id()));

create policy "assinaturas: cliente e gerência editam"
  on public.assinaturas for update to authenticated
  using (cliente_id = (select private.meu_cliente_id()) or private.gerencia_unidade(unidade_id))
  with check (cliente_id = (select private.meu_cliente_id()) or private.gerencia_unidade(unidade_id));

create policy "assinaturas: cliente remove a sua"
  on public.assinaturas for delete to authenticated
  using (cliente_id = (select private.meu_cliente_id()));

create policy "itens_assinatura: visíveis com a assinatura"
  on public.itens_assinatura for select to authenticated
  using (exists (select 1 from public.assinaturas a where a.id = assinatura_id));

create policy "itens_assinatura: cliente gerencia os seus"
  on public.itens_assinatura for all to authenticated
  using (exists (select 1 from public.assinaturas a
                  where a.id = assinatura_id and a.cliente_id = (select private.meu_cliente_id())))
  with check (exists (select 1 from public.assinaturas a
                       where a.id = assinatura_id and a.cliente_id = (select private.meu_cliente_id())));

-- ---------------------------------------------------------------------------
-- Combos (vitrine pública) e cupons (só gestão; validação via RPC no checkout)
-- ---------------------------------------------------------------------------
create policy "combos: todos veem os ativos"
  on public.combos for select to anon, authenticated
  using ((ativo and (inicio is null or inicio <= now()) and (fim is null or fim > now()))
         or (select private.eh_funcionario()));

create policy "combos: dono e gerente gerenciam"
  on public.combos for all to authenticated
  using ((select private.eh_dono()) or (unidade_id is not null and private.gerencia_unidade(unidade_id)))
  with check ((select private.eh_dono()) or (unidade_id is not null and private.gerencia_unidade(unidade_id)));

create policy "itens_combo: todos veem"
  on public.itens_combo for select to anon, authenticated
  using (exists (select 1 from public.combos c where c.id = combo_id));

create policy "itens_combo: dono e gerente gerenciam"
  on public.itens_combo for all to authenticated
  using (exists (select 1 from public.combos c where c.id = combo_id
                  and ((select private.eh_dono()) or (c.unidade_id is not null and private.gerencia_unidade(c.unidade_id)))))
  with check (exists (select 1 from public.combos c where c.id = combo_id
                       and ((select private.eh_dono()) or (c.unidade_id is not null and private.gerencia_unidade(c.unidade_id)))));

create policy "cupons: dono e gerentes veem"
  on public.cupons for select to authenticated
  using ((select private.minha_funcao()) in ('dono', 'gerente'));

create policy "cupons: dono gerencia"
  on public.cupons for all to authenticated
  using ((select private.eh_dono())) with check ((select private.eh_dono()));

-- ---------------------------------------------------------------------------
-- Realtime: balcão e admin assinam pedidos; cliente assina o próprio pedido.
-- (o Realtime respeita as políticas de select acima)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.pedidos, public.itens_pedido, public.unidades, public.estoque;
  end if;
end $$;
