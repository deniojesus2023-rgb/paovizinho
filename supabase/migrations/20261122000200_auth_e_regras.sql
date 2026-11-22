-- =============================================================================
-- Pão Vizinho — autenticação por celular, papéis e regras de integridade
-- =============================================================================

-- Funções auxiliares ficam num schema não exposto pela API.
create schema if not exists private;
grant usage on schema private to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Quem é o usuário logado?
-- security definer: leem funcionarios/clientes sem passar pela RLS (evita recursão).
-- ---------------------------------------------------------------------------
create or replace function private.meu_cliente_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select c.id from public.clientes c where c.auth_user_id = auth.uid()
$$;

create or replace function private.minha_funcao()
returns public.funcao_funcionario language sql stable security definer set search_path = '' as $$
  select f.funcao from public.funcionarios f where f.auth_user_id = auth.uid() and f.ativo
$$;

create or replace function private.minha_unidade()
returns uuid language sql stable security definer set search_path = '' as $$
  select f.unidade_id from public.funcionarios f where f.auth_user_id = auth.uid() and f.ativo
$$;

create or replace function private.meu_funcionario_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select f.id from public.funcionarios f where f.auth_user_id = auth.uid() and f.ativo
$$;

create or replace function private.eh_dono()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.minha_funcao() = 'dono', false)
$$;

create or replace function private.eh_funcionario()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.minha_funcao() is not null
$$;

-- (coalesce: estas funções nunca devolvem null, para serem seguras em IF NOT …)

-- Qualquer função da equipe vinculada à unidade (ou o dono).
create or replace function private.acessa_unidade(p_unidade uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
         private.eh_dono()
        or (private.minha_funcao() is not null and private.minha_unidade() = p_unidade),
         false)
$$;

-- Quem opera pedidos e estoque: dono, gerente e balcão.
create or replace function private.opera_unidade(p_unidade uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
         private.eh_dono()
        or (private.minha_funcao() in ('gerente', 'balcao') and private.minha_unidade() = p_unidade),
         false)
$$;

-- Quem administra a unidade: dono e gerente dela.
create or replace function private.gerencia_unidade(p_unidade uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
         private.eh_dono()
        or (private.minha_funcao() = 'gerente' and private.minha_unidade() = p_unidade),
         false)
$$;

-- O funcionário pode ver um cliente que mora na unidade dele ou pediu nela.
create or replace function private.cliente_visivel_para_equipe(p_cliente uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
         private.eh_dono()
        or exists (select 1 from public.enderecos e
                    where e.cliente_id = p_cliente and private.acessa_unidade(e.unidade_id))
        or exists (select 1 from public.pedidos p
                    where p.cliente_id = p_cliente and private.acessa_unidade(p.unidade_id)),
         false)
$$;

-- Chamada vinda da API (usuário final), e não do service_role / cron / funções internas.
create or replace function private.chamada_de_usuario()
returns boolean language sql stable as $$
  select current_user in ('authenticated', 'anon')
$$;

revoke all on all functions in schema private from public;
grant execute on all functions in schema private to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Vínculo automático no login por celular
-- Quando alguém entra com um telefone já cadastrado pelo dono (equipe) ou pela
-- padaria (cliente), o registro é ligado ao usuário do Auth.
-- ---------------------------------------------------------------------------
create or replace function private.vincular_usuario_por_telefone()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.phone is null or new.phone = '' then
    return new;
  end if;

  update public.funcionarios
     set auth_user_id = new.id
   where telefone = new.phone and auth_user_id is null;

  update public.clientes
     set auth_user_id = new.id
   where telefone = new.phone and auth_user_id is null;

  return new;
end;
$$;

create trigger vincular_usuario_por_telefone
  after insert or update of phone on auth.users
  for each row execute function private.vincular_usuario_por_telefone();

-- ---------------------------------------------------------------------------
-- RPC: concluir o cadastro do morador (tela "Onde você mora?")
-- O telefone vem do Auth (já verificado pelo código), nunca do formulário.
-- ---------------------------------------------------------------------------
create or replace function public.completar_cadastro(
  p_nome        text,
  p_unidade_id  uuid,
  p_bloco       text,
  p_apto        text,
  p_referencia  text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid       uuid := auth.uid();
  v_telefone  text;
  v_cliente   uuid;
begin
  if v_uid is null then
    raise exception 'É preciso entrar com o celular primeiro.' using errcode = '28000';
  end if;
  if coalesce(trim(p_nome), '') = '' then
    raise exception 'Conta pra gente o seu nome.' using errcode = '22023';
  end if;
  if coalesce(trim(p_bloco), '') = '' or coalesce(trim(p_apto), '') = '' then
    raise exception 'Informe bloco e apartamento.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.unidades u where u.id = p_unidade_id and u.ativa) then
    raise exception 'Condomínio não atendido.' using errcode = '22023';
  end if;

  select u.phone into v_telefone from auth.users u where u.id = v_uid;
  if v_telefone is null or v_telefone = '' then
    raise exception 'Celular não verificado.' using errcode = '28000';
  end if;

  -- cliente já existente (pelo usuário ou pelo telefone)
  select c.id into v_cliente
    from public.clientes c
   where c.auth_user_id = v_uid or (c.telefone = v_telefone and c.auth_user_id is null)
   limit 1;

  if v_cliente is null then
    insert into public.clientes (auth_user_id, nome, telefone)
    values (v_uid, trim(p_nome), v_telefone)
    returning id into v_cliente;
  else
    update public.clientes
       set nome = trim(p_nome), auth_user_id = v_uid
     where id = v_cliente;
  end if;

  update public.enderecos set principal = false where cliente_id = v_cliente and principal;

  insert into public.enderecos (cliente_id, unidade_id, apelido, bloco, apto, referencia, principal)
  values (v_cliente, p_unidade_id, 'Casa', upper(trim(p_bloco)), trim(p_apto),
          nullif(trim(coalesce(p_referencia, '')), ''), true);

  return v_cliente;
end;
$$;

revoke all on function public.completar_cadastro(text, uuid, text, text, text) from public, anon;
grant execute on function public.completar_cadastro(text, uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: quem sou eu? (usado pelos apps para decidir a tela após o login)
-- ---------------------------------------------------------------------------
create or replace function public.meu_perfil()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'cliente', (
      select jsonb_build_object('id', c.id, 'nome', c.nome, 'telefone', c.telefone)
        from public.clientes c where c.auth_user_id = auth.uid()
    ),
    'funcionario', (
      select jsonb_build_object('id', f.id, 'nome', f.nome, 'funcao', f.funcao,
                                'unidade_id', f.unidade_id, 'turno', f.turno)
        from public.funcionarios f where f.auth_user_id = auth.uid() and f.ativo
    )
  )
$$;

revoke all on function public.meu_perfil() from public, anon;
grant execute on function public.meu_perfil() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: chave "Recebendo pedidos / Pausado" do balcão
-- ---------------------------------------------------------------------------
create or replace function public.definir_recebendo_pedidos(p_unidade_id uuid, p_aberta boolean)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.opera_unidade(p_unidade_id) then
    raise exception 'Sem permissão para esta unidade.' using errcode = '42501';
  end if;
  update public.unidades set aberta = p_aberta where id = p_unidade_id;
end;
$$;

revoke all on function public.definir_recebendo_pedidos(uuid, boolean) from public, anon;
grant execute on function public.definir_recebendo_pedidos(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Máquina de estados do pedido
--   novo ─► separando ─► pronto ─► a_caminho ─► entregue   (entrega)
--                            └──────────────► retirado      (retirada)
--   novo | separando ─► cancelado
--   "pronto" só com todos os itens separados ou em falta.
--   Função "entrega" só faz pronto ─► a_caminho ─► entregue.
-- ---------------------------------------------------------------------------
create or replace function private.validar_status_pedido()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_ok boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  v_ok := case old.status
    when 'novo'      then new.status in ('separando', 'cancelado')
    when 'separando' then new.status in ('pronto', 'cancelado')
    when 'pronto'    then (new.tipo = 'entrega'  and new.status = 'a_caminho')
                       or (new.tipo = 'retirada' and new.status = 'retirado')
    when 'a_caminho' then new.status = 'entregue'
    else false
  end;

  if not v_ok then
    raise exception 'Transição de status inválida: % → %', old.status, new.status
      using errcode = '22023';
  end if;

  if private.chamada_de_usuario() and private.minha_funcao() = 'entrega'
     and new.status not in ('a_caminho', 'entregue') then
    raise exception 'A função entrega só marca "a caminho" e "entregue".' using errcode = '42501';
  end if;

  if new.status = 'pronto' and exists (
       select 1 from public.itens_pedido i
        where i.pedido_id = new.id and not i.separado and not i.em_falta) then
    raise exception 'Marque todos os itens como separados ou em falta.' using errcode = '22023';
  end if;

  case new.status
    when 'separando' then new.aceito_em    := now();
    when 'pronto'    then new.pronto_em    := now();
    when 'a_caminho' then new.saiu_em      := now();
    when 'entregue'  then new.concluido_em := now();
    when 'retirado'  then new.concluido_em := now();
    when 'cancelado' then new.cancelado_em := now();
    else null;
  end case;

  if private.chamada_de_usuario() then
    new.funcionario_id := coalesce(private.meu_funcionario_id(), new.funcionario_id);
  end if;

  return new;
end;
$$;

create trigger validar_status_pedido
  before update of status on public.pedidos
  for each row execute function private.validar_status_pedido();

-- Pela API, a equipe só muda status, "pago" e responsável. Valores e dono do
-- pedido mudam apenas por funções do servidor.
create or replace function private.proteger_campos_pedido()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Funções security definer (ex.: recálculo de itens em falta) rodam como dono
  -- do banco e passam direto.
  if not private.chamada_de_usuario() then
    return new;
  end if;

  if new.cliente_id    is distinct from old.cliente_id
  or new.unidade_id    is distinct from old.unidade_id
  or new.endereco_id   is distinct from old.endereco_id
  or new.tipo          is distinct from old.tipo
  or new.agendado_para is distinct from old.agendado_para
  or new.pagamento     is distinct from old.pagamento
  or new.recado        is distinct from old.recado
  or new.subtotal      is distinct from old.subtotal
  or new.taxa          is distinct from old.taxa
  or new.desconto      is distinct from old.desconto
  or new.total         is distinct from old.total
  or new.cupom_codigo  is distinct from old.cupom_codigo
  or new.assinatura_id is distinct from old.assinatura_id
  or new.criado_em     is distinct from old.criado_em then
    raise exception 'Só é possível alterar status e pagamento do pedido.' using errcode = '42501';
  end if;

  -- "pago" pela equipe só para pagamento na entrega (Pix/cartão vêm do webhook)
  if new.pago is distinct from old.pago and old.pagamento <> 'na_entrega' then
    raise exception 'Pagamento online é confirmado automaticamente.' using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger proteger_campos_pedido
  before update on public.pedidos
  for each row execute function private.proteger_campos_pedido();

-- Histórico de status
create or replace function private.registrar_evento_pedido()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.eventos_pedido (pedido_id, status, por)
    values (new.id, new.status, auth.uid());
  end if;
  return new;
end;
$$;

create trigger registrar_evento_pedido
  after insert or update of status on public.pedidos
  for each row execute function private.registrar_evento_pedido();

-- ---------------------------------------------------------------------------
-- Itens: a equipe só marca "separado" / "em falta", e só durante a separação.
-- Item em falta sai do total do pedido.
-- ---------------------------------------------------------------------------
create or replace function private.proteger_itens_pedido()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_status public.status_pedido;
begin
  if not private.chamada_de_usuario() then
    return new;
  end if;

  if new.pedido_id  is distinct from old.pedido_id
  or new.produto_id is distinct from old.produto_id
  or new.quantidade is distinct from old.quantidade
  or new.preco_unit is distinct from old.preco_unit
  or new.ponto      is distinct from old.ponto then
    raise exception 'Só é possível marcar o item como separado ou em falta.' using errcode = '42501';
  end if;

  select p.status into v_status from public.pedidos p where p.id = new.pedido_id;
  if v_status <> 'separando' then
    raise exception 'Os itens só podem ser marcados durante a separação.' using errcode = '22023';
  end if;

  return new;
end;
$$;

create trigger proteger_itens_pedido
  before update on public.itens_pedido
  for each row execute function private.proteger_itens_pedido();

create or replace function private.recalcular_total_pedido()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_subtotal numeric(10,2);
begin
  select coalesce(sum(i.quantidade * i.preco_unit) filter (where not i.em_falta), 0)
    into v_subtotal
    from public.itens_pedido i
   where i.pedido_id = new.pedido_id;

  update public.pedidos p
     set subtotal = v_subtotal,
         total    = greatest(v_subtotal + p.taxa - p.desconto, 0)
   where p.id = new.pedido_id;

  return new;
end;
$$;

create trigger recalcular_total_pedido
  after update of em_falta on public.itens_pedido
  for each row when (new.em_falta is distinct from old.em_falta)
  execute function private.recalcular_total_pedido();

-- Estoque: carimbo de atualização
create or replace function private.carimbar_estoque()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

create trigger carimbar_estoque
  before update on public.estoque
  for each row execute function private.carimbar_estoque();
