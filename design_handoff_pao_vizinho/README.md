# Handoff: Pão Vizinho — App do cliente, App do balcão e Painel admin

## Visão geral
Pão Vizinho é uma padaria que atende condomínios: cada unidade (padaria) fica dentro ou ao lado de um condomínio. O sistema tem 3 frentes conectadas a um único back-end:

1. **App do cliente** (celular) — o morador pede pão e itens de padaria, escolhe entrega no apartamento ou retirada no balcão, paga e acompanha o pedido. Também pode assinar o "Pão todo dia".
2. **App do balcão** (tablet em paisagem, na padaria) — o funcionário recebe pedidos, separa os itens, marca o que está em falta, avisa o cliente e conclui a entrega ou a retirada.
3. **Painel admin** (computador e celular) — o dono acompanha vendas e gerencia cardápio, estoque, assinaturas, clientes, combos, equipe e unidades.

## Sobre os arquivos de design
Os arquivos em `prototipos/` são **referências de design feitas em HTML**: protótipos que mostram o visual e o comportamento esperados. **Não são código de produção para copiar.** A tarefa é **recriar estas telas** em um projeto real. Se ainda não existe projeto, sugestão de stack:

- **Back-end:** Supabase (Postgres + Auth por telefone/OTP + Realtime + Row Level Security + Edge Functions + Cron)
- **App do cliente:** Expo (React Native) ou PWA em Next.js
- **App do balcão e Painel admin:** Next.js (web responsivo; o balcão roda no navegador do tablet em tela cheia)
- **Pagamento:** Pix e cartão via Mercado Pago ou Asaas
- **Avisos:** WhatsApp (API oficial da Meta ou Z-API)

Para abrir um protótipo, sirva a pasta `prototipos/` com um servidor estático (ex.: `npx serve prototipos`) e abra o `.dc.html` no navegador. Os arquivos dependem de `support.js` e da pasta `app/`.

## Fidelidade
**Alta fidelidade (hi-fi).** Cores, tipografia, espaçamentos, raios e textos são finais. Recriar fielmente. Os dados (nomes, preços, números) são exemplos.

---

## Design tokens

### Cores
| Token | Hex | Uso |
|---|---|---|
| chocolate | `#4A2512` | Texto principal, toasts, selos escuros |
| laranja | `#E8650A` | Ação primária, aba ativa, destaques |
| laranja-escuro | `#C25407` | Texto sobre pêssego, labels de destaque |
| pêssego | `#FDEBDC` | Fundo de item selecionado, banners suaves |
| caramelo | `#F2C997` | Avatares, barras secundárias de gráfico |
| creme | `#FFF6EA` | Fundo da boas-vindas (topo do degradê) |
| fundo-app | `#FFFBF5` | Fundo das telas |
| superfície | `#FFFFFF` | Cards, inputs, barras |
| areia | `#F5ECE0` | Placeholders de foto, ícones em caixa |
| areia-2 | `#F7F1E9` / `#F3EADF` | Fundos de seção, segmented control |
| borda | `#EEE4D7` | Bordas de cards e inputs |
| divisor | `#F3EADF` | Linhas entre itens de lista |
| texto-suave | `#8A6F5E` | Texto secundário, ícones inativos |
| desabilitado | `#C9B8A6` / `#E2D4C2` | Botões bloqueados, toggles desligados |
| sucesso | `#3F8F5A` (fundo `#E7F2EA`, texto `#2E6B43`) | Pronto, online, check |
| alerta | `#C9A227` (fundo `#FBF3D5`, texto `#8A6A00`) | Separando, estoque baixo |

### Tipografia
- **Red Hat Display** 500/700: títulos e números grandes. Letter-spacing `-.02em` (até `-.03em` em 32px+).
- **Lato** 400/700/900: todo o resto.
- **Material Symbols Rounded**: ícones (variação `FILL` 0 = inativo, 1 = ativo).
- Escala usada: 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 28, 30, 32, 36 px.
- Labels de seção: 12px, peso 700, letter-spacing `.06em`, MAIÚSCULAS, cor texto-suave.

### Raios
6, 10, 12, 14, 16, 18, 20, 22, 28, 32 px e `999px` (pílulas). Cards: 16–22. Botões grandes: 14–16. Bottom sheet: `32px 32px 0 0`.

### Sombras
- Card elevado: `0 8px 24px -12px rgba(74,37,18,.18)`
- Barra flutuante: `0 14px 30px -14px rgba(74,37,18,.35)`
- Botão laranja: `0 10px 20px -10px rgba(232,101,10,.7)`
- Toast: `0 12px 28px -8px rgba(74,37,18,.45)`

### Espaçamento
Base 4px. Padding lateral das telas mobile: 20–24px. Gap entre seções: 20–28px. Alvo de toque mínimo: 44px.

### Movimento
- Botões: `transform: scale(.97)` no `:active`, `transition .15s`.
- Troca de cor/seleção: `.2s–.25s`.
- Toast entra de cima: `transform .35s cubic-bezier(.2,.9,.3,1.2)` + `opacity .25s`; some após 1,8s.
- Botão da sacola dá um "pulo" (`scale 1.06`) ao adicionar item: `.25s cubic-bezier(.2,.9,.3,1.4)`.

---

## 1. App do cliente (`prototipos/app-cliente.dc.html`)
Frame de referência: 390×844 (iPhone). Navegação inferior: cápsula branca flutuante (64px de altura, 16px das laterais, 26px do fundo) com 4 ícones (Início, Pedidos, Todo dia, Conta), indicador de ponto laranja de 5px na aba ativa, e **botão redondo laranja da sacola** (64px) ao lado, com contador de itens (badge chocolate).

### Telas
1. **Boas-vindas** — fundo em degradê `#FFF6EA → #FDEBDC`, padrão de pãezinhos (`app/padrao-chocolate.svg`, 120×90, opacidade .07, com máscara radial que some em volta do símbolo). Símbolo em círculo de 168px com halo. Bottom sheet branco com alça, logo horizontal (150px), título "Seu pãozinho, pertinho de casa." (28px), subtítulo, botões "Entrar com WhatsApp" (laranja, 56px) e "Só dar uma olhada" (contorno, 52px), linha de Termos e Privacidade.
2. **Cadastro** — nome, celular (WhatsApp), condomínio, bloco/torre, apartamento, ponto de referência. Barra de progresso de 2 passos. CTA fixo "Começar a pedir".
3. **Início** — logo + endereço (abre Endereços). "Bom dia, Marina. / Vai o de sempre?" Card do último pedido com botão "Repetir pedido · R$ 10,40" e link "Ver outros pedidos". Cardápio com abas sublinhadas (Todos, Pães, Bolos, Café, Conveniência) e lista de produtos (thumb, nome, preço/unidade, botão + que vira controle −/qtd/+).
4. **Produto** — foto, nome, descrição, preço. Para pão francês: escolha do ponto (Clarinho, Moreninho, Bem moreninho). Quantidade. CTA "Colocar na sacola · total".
5. **Sacola** — itens com −/+, entrega no apê ou retirada no balcão, horário (Agora / 11h / 17h / Amanhã 6h), subtotal, taxa de entrega e total. CTA "Escolher pagamento".
6. **Pagamento** — Pix, cartão, pagar na entrega. Resumo. Recado para a equipe. CTA "Confirmar pedido".
7. **Acompanhar pedido** — status em 4 etapas (Recebido → Separando → A caminho → Entregue), barra de progresso, mensagem da atendente.
8. **Histórico** — pedido em andamento no topo e pedidos anteriores com botão "Repetir".
9. **Pão todo dia (assinatura)** — escolha dos itens do saquinho, dias da semana (S T Q Q S S D), horário (6h, 6h30, 7h), preço por semana, ativar ou pausar.
10. **Conta** — perfil, contadores, atalhos para Endereços, Pão todo dia, Histórico, Pagamentos, Avisos, Sair.
11. **Endereços** — endereços salvos com radio, adicionar endereço, aviso de que a entrega só vale dentro do condomínio.

### Regras
- Linguagem: o pão é sempre **"fresquinho"** (nunca "quentinho"). **Não usar o conceito de "fornada"** no app.
- Taxa de entrega de exemplo: R$ 2,00. Retirada é grátis.
- Toast ao adicionar item: "<Produto> na sacola".

---

## 2. App do balcão (`prototipos/app-funcionario.dc.html`)
Frame de referência: tablet em paisagem, 1194×834.

### Layout
- **Topo (68px, branco):** logo · divisor · "BALCÃO / Jardim das Flores" · filtros em pílula (Todos · N, Entregas · N, Retiradas · N) · chave "Recebendo pedidos / Pausado" · funcionário (avatar, nome, turno e hora).
- **Esquerda (fundo `#F7F1E9`):** 3 colunas kanban — **Novos** (ponto laranja), **Separando** (ponto amarelo `#C9A227`), **Prontos** (ponto verde; inclui "a caminho"). Card do pedido: #número, pílula de horário ("Entregar já" em pêssego, ou "Retira 7h30"), nome, bloco/apto, resumo dos itens, tipo (ícone porta = entrega, loja = retirada) e total. Card selecionado: borda laranja de 2px.
- **Direita (400px, branco):** detalhe do pedido — etapa, número, hora e forma de pagamento, botão "Avisar" (WhatsApp), cliente, tipo e horário, **lista de itens com checkbox** (32px, verde ao marcar) e botão **"Em falta"** por item, recado do cliente (fundo pêssego), total e CTA.

### Fluxo de status (máquina de estados)
```
novo ──Aceitar e separar──► separando ──Pedido pronto──► pronto
  │                         (só libera com todos os itens marcados ou em falta)
  └─Recusar─► cancelado
pronto ──Saiu para entrega──► a_caminho ──Marcar entregue──► entregue   (entrega)
pronto ──Cliente retirou──────────────────────────────────► retirado   (retirada)
```
- Marcar **"Em falta"**: risca o item, tira do total, envia WhatsApp ao cliente e estorna o valor.
- Cada mudança de status: atualiza o app do cliente em tempo real e dispara um aviso no WhatsApp nas etapas "pronto", "a caminho" e "entregue".
- "Pausado": a unidade para de aceitar pedidos novos (o app do cliente mostra a loja fechada).

---

## 3. Painel admin (`prototipos/painel-admin.dc.html`)
- **1a, computador (1440×900):** sidebar de 248px com logo, **seletor de unidade** (Todas, Jardim das Flores, Vila Verde, Parque das Águas) e menu: Visão geral, Pedidos (badge), Cardápio e estoque (badge), Assinaturas, Clientes, Combos e promoções, Equipe, Unidades. Topo com título, unidade e data, e período (Hoje, 7 dias, 30 dias) ou botão de criar.
  - **Visão geral:** 4 KPIs (Faturamento, Pedidos, Ticket médio, Assinantes ativos), gráfico de vendas por horário (6h–19h, barra de pico em laranja), Mais vendidos (barras), Pedidos agora (tempo real) e alertas (esgotado, estoque baixo, unidade pausada).
  - **Demais seções:** tabela padrão com busca, filtros em chips, cabeçalho em `#F7F1E9` e linhas com thumb, textos, pílulas de status e toggles (À venda, Ativo).
- **1b, celular (390×844):** resumo da visão geral (faturamento, mini-KPIs, gráfico e pedidos agora).

### Permissões
| Função | Acesso |
|---|---|
| Dono / Admin | Tudo, todas as unidades |
| Gerente | Unidade dele, completa |
| Balcão | Pedidos e estoque da unidade dele |
| Entrega | Só pedidos prontos e a caminho da unidade dele |

---

## Modelo de dados sugerido (Postgres / Supabase)
```
unidades(id, nome, endereco, aberta bool, taxa_entrega, horarios jsonb)
produtos(id, nome, descricao, categoria, preco, unidade_medida, foto_url, tem_ponto bool)
estoque(unidade_id, produto_id, quantidade, a_venda bool)
clientes(id, auth_user_id, nome, telefone, created_at)
enderecos(id, cliente_id, unidade_id, bloco, apto, referencia, principal bool)
funcionarios(id, auth_user_id, nome, telefone, funcao enum[dono,gerente,balcao,entrega], unidade_id null=todas)
pedidos(id, numero, cliente_id, unidade_id, endereco_id, tipo enum[entrega,retirada],
        horario enum/agendado_para, status enum[novo,separando,pronto,a_caminho,entregue,retirado,cancelado],
        pagamento enum[pix,cartao,na_entrega], pago bool, recado, subtotal, taxa, total,
        criado_em, aceito_em, pronto_em, concluido_em, funcionario_id)
itens_pedido(id, pedido_id, produto_id, quantidade, preco_unit, ponto, separado bool, em_falta bool)
assinaturas(id, cliente_id, unidade_id, endereco_id, dias int[], horario, ativa bool, pausada_ate)
itens_assinatura(assinatura_id, produto_id, quantidade)
combos(id, nome, preco, ativo, inicio, fim) · itens_combo(combo_id, produto_id, quantidade)
cupons(codigo, tipo, valor, ativo, usos)
eventos_pedido(id, pedido_id, status, por, em)  -- histórico/auditoria
```

### Tempo real e automações
- **Realtime:** o balcão assina `pedidos where unidade_id = X and status not in (concluídos)`. O cliente assina o próprio pedido. O admin assina tudo.
- **RLS:** o cliente vê só os próprios dados. O funcionário vê só a unidade dele. O dono vê tudo.
- **Cron (madrugada):** gera os pedidos do dia a partir das `assinaturas` ativas para aquele dia da semana.
- **Webhooks:** confirmação do Pix marca `pago = true`. Mudanças de status disparam o WhatsApp.

## Ordem de construção sugerida
1. Banco, autenticação por celular e RLS.
2. Cardápio, sacola e pedido no app do cliente.
3. App do balcão com Realtime e a máquina de status.
4. Acompanhamento do pedido e WhatsApp.
5. Pagamento Pix e cartão.
6. Assinatura "Pão todo dia" e Cron.
7. Painel admin (visão geral, cardápio e estoque, equipe, unidades).

## Assets
- `prototipos/app/` — logos e símbolo em SVG usados nas telas (`logo-horizontal-cor.svg`, `logo-horizontal-negativo.svg`, `simbolo-cor.svg`, `simbolo-negativo.svg`, `simbolo-simplificado-chocolate.svg`, `padrao-chocolate.svg`).
- `marca/svg/` — kit completo da marca (horizontal, vertical, símbolo, ícones, grafismos).
- Fotos de produtos: ainda não existem. Os protótipos usam placeholders.
- Ícones: Google Material Symbols Rounded.

## Arquivos
- `prototipos/app-cliente.dc.html` — app do cliente (11 telas; lista de atalhos ao lado do celular)
- `prototipos/app-funcionario.dc.html` — app do balcão (tablet)
- `prototipos/painel-admin.dc.html` — painel admin (computador e celular)
- `prototipos/support.js` — runtime necessário para abrir os protótipos
