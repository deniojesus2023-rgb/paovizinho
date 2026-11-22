-- =============================================================================
-- Pão Vizinho — esquema base
-- Unidades, cardápio/estoque, clientes, equipe, pedidos, assinaturas, combos.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------
create type public.funcao_funcionario as enum ('dono', 'gerente', 'balcao', 'entrega');
create type public.tipo_pedido        as enum ('entrega', 'retirada');
create type public.status_pedido      as enum ('novo', 'separando', 'pronto', 'a_caminho', 'entregue', 'retirado', 'cancelado');
create type public.forma_pagamento    as enum ('pix', 'cartao', 'na_entrega');
create type public.ponto_pao          as enum ('clarinho', 'moreninho', 'bem_moreninho');
create type public.tipo_cupom         as enum ('percentual', 'valor_fixo');

-- ---------------------------------------------------------------------------
-- Unidades (cada padaria atende um condomínio)
-- ---------------------------------------------------------------------------
create table public.unidades (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,                      -- "Jardim das Flores"
  condominio    text not null,                      -- "Residencial Jardim das Flores"
  endereco      text,
  aberta        boolean not null default true,      -- false = "Pausado" no balcão
  taxa_entrega  numeric(10,2) not null default 2.00 check (taxa_entrega >= 0),
  horarios      jsonb not null default '["11:00","17:00"]'::jsonb, -- horários agendáveis além de "Agora"
  ativa         boolean not null default true,      -- unidade em operação (painel > Unidades)
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Cardápio (global) e estoque (por unidade)
-- ---------------------------------------------------------------------------
create table public.produtos (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,
  nome            text not null,
  descricao_curta text,
  descricao       text,
  categoria       text not null check (categoria in ('paes', 'bolos', 'doces', 'cafe', 'conveniencia')),
  preco           numeric(10,2) not null check (preco >= 0),
  unidade_medida  text not null default 'unidade',  -- "unidade", "fatia", "300 ml"…
  foto_url        text,
  tem_ponto       boolean not null default false,   -- pão francês: clarinho / moreninho / bem moreninho
  ativo           boolean not null default true,
  ordem           integer not null default 0,
  created_at      timestamptz not null default now()
);

create table public.estoque (
  unidade_id      uuid not null references public.unidades (id) on delete cascade,
  produto_id      uuid not null references public.produtos (id) on delete cascade,
  quantidade      integer,                          -- null = não controla (ex.: café coado)
  estoque_minimo  integer not null default 0,       -- alerta de "estoque baixo"
  a_venda         boolean not null default true,
  atualizado_em   timestamptz not null default now(),
  primary key (unidade_id, produto_id)
);

-- ---------------------------------------------------------------------------
-- Clientes e endereços
-- Telefone sempre em E.164 sem "+" (mesmo formato de auth.users.phone): 5511987654321
-- ---------------------------------------------------------------------------
create table public.clientes (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users (id) on delete set null,
  nome          text not null check (length(trim(nome)) > 0),
  telefone      text not null unique check (telefone ~ '^[0-9]{10,15}$'),
  created_at    timestamptz not null default now()
);

create table public.enderecos (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clientes (id) on delete cascade,
  unidade_id  uuid not null references public.unidades (id),
  apelido     text not null default 'Casa',
  bloco       text not null,
  apto        text not null,
  referencia  text,
  principal   boolean not null default false,
  created_at  timestamptz not null default now()
);
create unique index enderecos_um_principal on public.enderecos (cliente_id) where principal;
create index enderecos_cliente on public.enderecos (cliente_id);

-- ---------------------------------------------------------------------------
-- Equipe
-- unidade_id null = todas as unidades (só para "dono").
-- O dono cadastra pelo telefone; o vínculo com auth.users acontece no 1º login.
-- ---------------------------------------------------------------------------
create table public.funcionarios (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users (id) on delete set null,
  nome          text not null,
  telefone      text not null unique check (telefone ~ '^[0-9]{10,15}$'),
  funcao        public.funcao_funcionario not null,
  unidade_id    uuid references public.unidades (id),
  turno         text,                                -- "Manhã", "Tarde"
  ativo         boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint funcionario_unidade_obrigatoria check (funcao = 'dono' or unidade_id is not null)
);

-- ---------------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------------
create table public.pedidos (
  id              uuid primary key default gen_random_uuid(),
  numero          bigint generated always as identity (start with 1001) unique,
  cliente_id      uuid not null references public.clientes (id),
  unidade_id      uuid not null references public.unidades (id),
  endereco_id     uuid references public.enderecos (id),
  tipo            public.tipo_pedido not null,
  agendado_para   timestamptz,                       -- null = "Agora"
  status          public.status_pedido not null default 'novo',
  pagamento       public.forma_pagamento not null,
  pago            boolean not null default false,
  recado          text,
  subtotal        numeric(10,2) not null default 0 check (subtotal >= 0),
  taxa            numeric(10,2) not null default 0 check (taxa >= 0),
  desconto        numeric(10,2) not null default 0 check (desconto >= 0),
  total           numeric(10,2) not null default 0 check (total >= 0),
  cupom_codigo    text,
  assinatura_id   uuid,                              -- FK adicionada abaixo
  funcionario_id  uuid references public.funcionarios (id),
  criado_em       timestamptz not null default now(),
  aceito_em       timestamptz,
  pronto_em       timestamptz,
  saiu_em         timestamptz,
  concluido_em    timestamptz,
  cancelado_em    timestamptz,
  constraint entrega_tem_endereco check (tipo = 'retirada' or endereco_id is not null)
);
create index pedidos_unidade_status on public.pedidos (unidade_id, status);
create index pedidos_cliente_data   on public.pedidos (cliente_id, criado_em desc);
create index pedidos_criado_em      on public.pedidos (criado_em desc);

create table public.itens_pedido (
  id          uuid primary key default gen_random_uuid(),
  pedido_id   uuid not null references public.pedidos (id) on delete cascade,
  produto_id  uuid not null references public.produtos (id),
  quantidade  integer not null check (quantidade > 0),
  preco_unit  numeric(10,2) not null check (preco_unit >= 0),
  ponto       public.ponto_pao,
  separado    boolean not null default false,
  em_falta    boolean not null default false,
  constraint separado_ou_em_falta check (not (separado and em_falta))
);
create index itens_pedido_pedido on public.itens_pedido (pedido_id);

-- Histórico / auditoria de status
create table public.eventos_pedido (
  id         bigint generated always as identity primary key,
  pedido_id  uuid not null references public.pedidos (id) on delete cascade,
  status     public.status_pedido not null,
  por        uuid references auth.users (id) on delete set null,
  em         timestamptz not null default now()
);
create index eventos_pedido_pedido on public.eventos_pedido (pedido_id, em);

-- ---------------------------------------------------------------------------
-- Assinatura "Pão todo dia"
-- dias: ISO 1 = segunda … 7 = domingo (S T Q Q S S D)
-- ---------------------------------------------------------------------------
create table public.assinaturas (
  id           uuid primary key default gen_random_uuid(),
  cliente_id   uuid not null references public.clientes (id) on delete cascade,
  unidade_id   uuid not null references public.unidades (id),
  endereco_id  uuid references public.enderecos (id),
  tipo         public.tipo_pedido not null default 'entrega',
  dias         smallint[] not null default '{1,2,3,4,5}',
  horario      time not null default '06:30',
  pagamento    public.forma_pagamento not null default 'pix',
  ativa        boolean not null default true,
  pausada_ate  date,
  created_at   timestamptz not null default now(),
  constraint dias_validos check (dias <@ '{1,2,3,4,5,6,7}'::smallint[] and cardinality(dias) > 0),
  constraint assinatura_entrega_tem_endereco check (tipo = 'retirada' or endereco_id is not null)
);
create index assinaturas_cliente on public.assinaturas (cliente_id);

create table public.itens_assinatura (
  assinatura_id  uuid not null references public.assinaturas (id) on delete cascade,
  produto_id     uuid not null references public.produtos (id),
  quantidade     integer not null check (quantidade > 0),
  ponto          public.ponto_pao,
  primary key (assinatura_id, produto_id)
);

alter table public.pedidos
  add constraint pedidos_assinatura_fk foreign key (assinatura_id) references public.assinaturas (id) on delete set null;

-- ---------------------------------------------------------------------------
-- Combos e cupons
-- ---------------------------------------------------------------------------
create table public.combos (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  descricao   text,
  selo        text,                                   -- "MAIS PEDIDO", "17H"
  preco       numeric(10,2) not null check (preco >= 0),
  unidade_id  uuid references public.unidades (id),   -- null = todas
  ativo       boolean not null default true,
  inicio      timestamptz,
  fim         timestamptz,
  created_at  timestamptz not null default now()
);

create table public.itens_combo (
  combo_id    uuid not null references public.combos (id) on delete cascade,
  produto_id  uuid not null references public.produtos (id),
  quantidade  integer not null check (quantidade > 0),
  primary key (combo_id, produto_id)
);

create table public.cupons (
  codigo      text primary key check (codigo = upper(codigo)),
  tipo        public.tipo_cupom not null,
  valor       numeric(10,2) not null check (valor > 0),
  ativo       boolean not null default true,
  usos        integer not null default 0,
  max_usos    integer,
  valido_ate  timestamptz,
  created_at  timestamptz not null default now()
);
