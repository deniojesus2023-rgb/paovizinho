# Pão Vizinho

Padaria de condomínio: app do cliente, app do balcão e painel admin sobre um único back-end Supabase.
Design de referência: [`design_handoff_pao_vizinho/`](design_handoff_pao_vizinho/README.md).

```
supabase/                 back-end (Postgres, Auth, RLS, Edge Functions)
  migrations/             esquema, regras e políticas de acesso
  functions/send-sms/     envia o código de login pelo WhatsApp (hook do Auth)
  seed.sql                3 unidades, cardápio, estoque, combos e equipe de teste
  testes/rls.sql          testes das permissões e da máquina de status
web/                      Next.js 16 (App Router): cliente (PWA), /balcao e /admin
```

## Etapas (ordem do handoff)

- [x] **1. Banco, autenticação por celular e RLS**
- [ ] 2. Cardápio, sacola e pedido no app do cliente
- [ ] 3. App do balcão com Realtime e a máquina de status
- [ ] 4. Acompanhamento do pedido e WhatsApp
- [ ] 5. Pagamento Pix e cartão
- [ ] 6. Assinatura "Pão todo dia" e Cron
- [ ] 7. Painel admin

## Rodando localmente

Pré-requisitos: Node 20+, Docker (para o Supabase local).

```bash
cd web
npm install
npm run db:start          # sobe o Supabase local, aplica migrations + seed
cp .env.example .env.local   # preencha com a API URL e a Publishable key mostradas
npm run dev
```

Antes do `db:start`, crie `supabase/.env` (fica fora do git):

```
SEND_SMS_HOOK_SECRET=v1,whsec_<base64 aleatório>
WHATSAPP_PROVIDER=log
```

e rode a função do hook em outro terminal: `npm run functions:serve`.

### Logins de teste

O código é sempre **123456** (definido em `[auth.sms.test_otp]` do `supabase/config.toml`):

| Celular | Quem |
|---|---|
| (11) 98765-4321 | cliente novo → cai no cadastro |
| (11) 90000-0001 | dono → `/admin` |
| (11) 90000-0002 | Cida, balcão Jardim das Flores → `/balcao` |

### Testes do banco

```bash
npm run db:test           # roda supabase/testes/rls.sql (tudo em transação, nada fica gravado)
```

## Autenticação

- Login só por celular com código (OTP). O Supabase Auth gera o código e chama o hook
  **Send SMS** → Edge Function `send-sms`, que entrega pelo WhatsApp
  (`WHATSAPP_PROVIDER=meta` para a API oficial, `zapi` para Z-API, `log` para só imprimir).
- Primeiro login de um cliente → tela "Onde você mora?" → RPC `completar_cadastro`
  (o telefone vem do Auth, nunca do formulário).
- Equipe: o dono cadastra a pessoa pelo telefone em `funcionarios`; no primeiro login
  um trigger em `auth.users` faz o vínculo. Depois do login, `meu_perfil()` decide o destino:
  dono/gerente → `/admin`, balcão/entrega → `/balcao`, cliente → `/inicio`.
- `web/src/proxy.ts` renova a sessão e exige login em `/cadastro`, `/conta`, `/balcao`, `/admin`.

## Regras no banco (RLS + triggers)

| Função | Acesso |
|---|---|
| Cliente | só os próprios dados, pedidos e assinaturas |
| Dono | tudo, todas as unidades |
| Gerente | a unidade dele completa; cadastra balcão e entrega da unidade |
| Balcão | pedidos e estoque da unidade; pausa/reabre a loja |
| Entrega | só pedidos de entrega prontos e a caminho da unidade |

- **Máquina de status** (`validar_status_pedido`): `novo → separando → pronto → a_caminho → entregue`
  ou `pronto → retirado`; `novo|separando → cancelado`. "Pronto" só com todos os itens
  separados ou em falta. Cada mudança carimba o horário e grava em `eventos_pedido`.
- Item marcado **em falta** sai do subtotal/total automaticamente.
- Pela API, a equipe só altera status e "pago" (este só para pagamento na entrega);
  valores e dados do pedido só mudam por funções do servidor.
- Pedidos são criados por RPC (etapa 2), não por insert direto do cliente.
- Realtime habilitado em `pedidos`, `itens_pedido`, `unidades` e `estoque`.

## Produção

1. Crie o projeto no Supabase e rode `supabase link` + `supabase db push`.
2. Em Authentication → Providers → Phone, ative o login por celular.
3. Em Authentication → Hooks, ative **Send SMS** apontando para a função `send-sms` e
   copie o segredo para `supabase secrets set SEND_SMS_HOOK_SECRET=...`.
4. `supabase functions deploy send-sms` e configure as credenciais do WhatsApp
   (`META_WA_TOKEN`, `META_WA_PHONE_NUMBER_ID`, `META_WA_TEMPLATE` ou `ZAPI_*`).
   Na Meta, o modelo precisa ser da categoria **Autenticação**, em pt_BR.
