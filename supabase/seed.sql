-- Dados de exemplo (desenvolvimento local). Valores dos protótipos.
insert into public.unidades (id, nome, condominio, endereco, taxa_entrega, horarios) values
  ('11111111-1111-4111-8111-000000000001', 'Jardim das Flores', 'Residencial Jardim das Flores', 'Térreo do Bloco A', 2.00, '["11:00","17:00"]'),
  ('11111111-1111-4111-8111-000000000002', 'Vila Verde',        'Condomínio Vila Verde',          'Ao lado da portaria', 2.00, '["11:00","17:00"]'),
  ('11111111-1111-4111-8111-000000000003', 'Parque das Águas',  'Parque das Águas Residence',     'Loja 2',              2.00, '["11:00","17:00"]');

insert into public.produtos (slug, nome, descricao_curta, descricao, categoria, preco, unidade_medida, tem_ponto, ordem) values
  ('frances',  'Pão francês',      'Crocante por fora, macio por dentro', 'Casquinha crocante e miolo macio. Feito todo dia aqui na padaria.', 'paes', 0.90, 'unidade', true, 1),
  ('queijo',   'Pão de queijo',    'Feito na casa, queijo meia-cura',     'Feito na casa com queijo meia-cura. Assado na hora.',               'paes', 1.50, 'unidade', false, 2),
  ('leite',    'Pão de leite',     'Fofinho, bom para o lanche',          'Massa fofinha e levemente adocicada.',                               'paes', 1.20, 'unidade', false, 3),
  ('cenoura',  'Bolo de cenoura',  'Com cobertura de chocolate',          'Bolo caseiro com cobertura de chocolate.',                           'bolos', 8.00, 'fatia', false, 4),
  ('fuba',     'Bolo de fubá',     'Receita de vó, com erva-doce',        'Receita de família, com erva-doce.',                                 'bolos', 7.00, 'fatia', false, 5),
  ('cafe',     'Café coado',       'Coado na hora',                       'Café coado na hora, 300 ml.',                                        'cafe', 5.00, '300 ml', false, 6),
  ('leitecx',  'Leite integral',   'Caixa de 1 litro',                    'Leite integral, caixa de 1 litro.',                                  'conveniencia', 6.50, '1 L', false, 7),
  ('manteiga', 'Manteiga com sal', 'Pote de 200 g',                       'Manteiga com sal, pote de 200 g.',                                   'conveniencia', 11.00, '200 g', false, 8);

insert into public.estoque (unidade_id, produto_id, quantidade, estoque_minimo, a_venda)
select u.id, p.id,
       case p.slug when 'frances' then 420 when 'queijo' then 180 when 'leite' then 95
                   when 'cenoura' then 16 when 'fuba' then 8 when 'cafe' then null
                   when 'leitecx' then 24 else 6 end,
       case p.slug when 'frances' then 60 when 'cafe' then 0 else 4 end,
       true
  from public.unidades u cross join public.produtos p;

with c as (
  insert into public.combos (nome, descricao, selo, preco) values
    ('Café da manhã',   '6 franceses, manteiga e café coado', 'MAIS PEDIDO', 19.90),
    ('Lanche da tarde', '2 fatias de bolo e 2 cafés',         '17H',         22.00),
    ('Lancheira',       '4 pães de leite e 1 L de leite',     'ESCOLA',      10.50)
  returning id, nome
)
insert into public.itens_combo (combo_id, produto_id, quantidade)
select c.id, p.id, x.qtd
  from c
  join (values ('Café da manhã', 'frances', 6), ('Café da manhã', 'manteiga', 1), ('Café da manhã', 'cafe', 1),
               ('Lanche da tarde', 'cenoura', 1), ('Lanche da tarde', 'fuba', 1), ('Lanche da tarde', 'cafe', 2),
               ('Lancheira', 'leite', 4), ('Lancheira', 'leitecx', 1)) as x(combo, slug, qtd) on x.combo = c.nome
  join public.produtos p on p.slug = x.slug;

-- Equipe de teste (os números estão em [auth.sms.test_otp] do config.toml, código 123456).
-- O vínculo com o usuário do Auth acontece no primeiro login.
insert into public.funcionarios (nome, telefone, funcao, unidade_id, turno) values
  ('Dono Pão Vizinho', '5511900000001', 'dono',   null, null),
  ('Cida',             '5511900000002', 'balcao', '11111111-1111-4111-8111-000000000001', 'Manhã');
