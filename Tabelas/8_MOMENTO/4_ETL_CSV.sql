-- Fluxo ETL de referência para Tabelas/8_MOMENTO/vendas_campanha_bruto.csv
-- MySQL 8.0+. Execute no mesmo schema/sessão do banco momento.
-- Política: importar o CSV sem transformação; carregar linhas válidas e manter
-- linhas pendentes/rejeitadas em etl_rejeicoes. Um pedido pode ficar parcial
-- enquanto uma de suas linhas aguarda revisão, conforme permitido no README.
USE momento;

-- EXTRACT: escolha o caminho local acessível ao cliente MySQL.
-- Alternativa: MySQL Workbench > Table Data Import Wizard, tabela stg_vendas_csv,
-- separador ;, primeira linha como cabeçalho e colunas correspondentes abaixo.
-- LOAD DATA LOCAL INFILE 'C:/caminho/vendas_campanha_bruto.csv'
-- INTO TABLE stg_vendas_csv
-- CHARACTER SET utf8mb4
-- FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES
-- (source_row_id, lote_origem, pedido_ref, item_seq, data_venda_raw, locale_origem,
--  sku_raw, quantidade_raw, preco_unitario_raw, moeda_raw, email_vendedor_raw,
--  canal_raw, status_raw);
-- Não use SET no LOAD DATA: os campos da tabela de staging devem permanecer brutos.

-- 1. Normaliza somente espaços/caixa e interpreta valores quando o locale conhecido
-- permite. Os campos originais continuam em stg_vendas_csv para rastreabilidade.
DROP TEMPORARY TABLE IF EXISTS etl_csv_normalizada;
CREATE TEMPORARY TABLE etl_csv_normalizada AS
WITH brutos AS (
  SELECT s.*,
         NULLIF(TRIM(s.pedido_ref), '') AS pedido_ref_n,
         NULLIF(TRIM(s.item_seq), '') AS item_seq_txt,
         NULLIF(TRIM(s.data_venda_raw), '') AS data_txt,
         NULLIF(UPPER(TRIM(s.locale_origem)), '') AS locale_n,
         NULLIF(UPPER(TRIM(s.sku_raw)), '') AS sku_n,
         NULLIF(TRIM(s.quantidade_raw), '') AS quantidade_txt,
         NULLIF(REGEXP_REPLACE(
           REPLACE(REPLACE(REPLACE(UPPER(TRIM(s.preco_unitario_raw)), 'US$', ''),
                           'R$', ''), '$', ''),
           '[[:space:]]', ''), '') AS preco_txt,
         NULLIF(UPPER(TRIM(s.moeda_raw)), '') AS moeda_n,
         NULLIF(LOWER(TRIM(s.email_vendedor_raw)), '') AS email_n,
         UPPER(TRIM(s.canal_raw)) AS canal_n,
         UPPER(TRIM(s.status_raw)) AS status_n
  FROM stg_vendas_csv s
),
convertidos AS (
  SELECT b.*,
         CASE
           WHEN b.item_seq_txt REGEXP '^[0-9]+$'
             THEN CAST(b.item_seq_txt AS UNSIGNED)
           ELSE NULL
         END AS item_seq_n,
         CASE
           WHEN b.quantidade_txt REGEXP '^[0-9]+$'
             THEN CAST(b.quantidade_txt AS UNSIGNED)
           ELSE NULL
         END AS quantidade_n,
         CASE
           WHEN b.locale_n = 'ISO'
             AND b.data_txt REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
             AND CAST(SUBSTRING(b.data_txt, 9, 2) AS UNSIGNED)
                 BETWEEN 1 AND DAY(LAST_DAY(STR_TO_DATE(
                   CONCAT(SUBSTRING(b.data_txt, 1, 4), '-',
                          SUBSTRING(b.data_txt, 6, 2), '-01'), '%Y-%m-%d')))
             THEN STR_TO_DATE(b.data_txt, '%Y-%m-%d')
           WHEN b.locale_n = 'PT-BR'
             AND b.data_txt REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
             AND CAST(SUBSTRING(b.data_txt, 1, 2) AS UNSIGNED)
                 BETWEEN 1 AND DAY(LAST_DAY(STR_TO_DATE(
                   CONCAT(SUBSTRING(b.data_txt, 7, 4), '-',
                          SUBSTRING(b.data_txt, 4, 2), '-01'), '%Y-%m-%d')))
             THEN STR_TO_DATE(b.data_txt, '%d/%m/%Y')
           WHEN b.locale_n = 'EN-US'
             AND b.data_txt REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
             AND CAST(SUBSTRING(b.data_txt, 4, 2) AS UNSIGNED)
                 BETWEEN 1 AND DAY(LAST_DAY(STR_TO_DATE(
                   CONCAT(SUBSTRING(b.data_txt, 7, 4), '-',
                          SUBSTRING(b.data_txt, 1, 2), '-01'), '%Y-%m-%d')))
             THEN STR_TO_DATE(b.data_txt, '%m/%d/%Y')
           ELSE NULL
         END AS data_venda_n,
         CASE
           WHEN b.locale_n = 'PT-BR'
             AND (b.preco_txt REGEXP '^[0-9]+(,[0-9]{1,2})?$'
               OR b.preco_txt REGEXP '^[0-9]{1,3}(\\.[0-9]{3})+(,[0-9]{1,2})?$')
             THEN CAST(REPLACE(REPLACE(b.preco_txt, '.', ''), ',', '.') AS DECIMAL(12,2))
           WHEN b.locale_n IN ('ISO', 'EN-US')
             AND (b.preco_txt REGEXP '^[0-9]+(\\.[0-9]{1,2})?$'
               OR b.preco_txt REGEXP '^[0-9]{1,3}(,[0-9]{3})+(\\.[0-9]{1,2})?$')
             THEN CAST(REPLACE(b.preco_txt, ',', '') AS DECIMAL(12,2))
           ELSE NULL
         END AS preco_n,
         CASE
           -- Lista explícita para esta base de exercícios. Amplie com uma tabela
           -- de moedas aprovada pela equipe, não com qualquer código de 3 letras.
           WHEN b.moeda_n IN ('USD', 'BRL', 'GBP', 'EUR', 'JPY', 'CAD', 'MXN',
                              'AUD', 'ZAR', 'ARS', 'PEN', 'CHF', 'INR', 'CNY')
             THEN b.moeda_n
           ELSE NULL
         END AS moeda_valida,
         CASE
           WHEN b.canal_n IN ('LOJA', 'LOJA FÍSICA', 'LOJA FISICA') THEN 1
           WHEN b.canal_n IN ('WEB', 'ONLINE') THEN 2
           WHEN b.canal_n = 'APP' THEN 3
           WHEN b.canal_n = 'MARKETPLACE' THEN 4
           WHEN b.canal_n = 'B2B' THEN 5
           ELSE NULL
         END AS canal_id_n,
         CASE
           WHEN b.status_n IN ('PAID', 'PAGO', 'CONCLUÍDA', 'CONCLUIDA') THEN 1
           WHEN b.status_n IN ('CANCELADO', 'CANCELADA', 'CANCELED', 'CANCELLED') THEN 3
           -- Não existe status pendente compatível na tabela status_venda da base.
           ELSE NULL
         END AS status_id_n
  FROM brutos b
)
SELECT c.*,
       p.produto_id,
       f.funcionario_id
FROM convertidos c
LEFT JOIN produtos p ON p.sku = c.sku_n
LEFT JOIN funcionarios f ON LOWER(f.email) = c.email_n;

-- 2. Marca duplicatas idênticas e conflitos na chave pedido/item.
DROP TEMPORARY TABLE IF EXISTS etl_csv_base;
CREATE TEMPORARY TABLE etl_csv_base AS
WITH payload AS (
  SELECT n.*,
         SHA2(CONCAT_WS(CHAR(31),
           COALESCE(n.pedido_ref_n, '∅'), COALESCE(CAST(n.item_seq_n AS CHAR), '∅'),
           COALESCE(CAST(n.data_venda_n AS CHAR), n.data_txt, '∅'),
           COALESCE(n.sku_n, '∅'),
           COALESCE(CAST(n.quantidade_n AS CHAR), n.quantidade_txt, '∅'),
           COALESCE(CAST(n.preco_n AS CHAR), n.preco_txt, '∅'),
           COALESCE(n.moeda_valida, n.moeda_n, '∅'),
           COALESCE(n.email_n, '∅'),
           COALESCE(CAST(n.canal_id_n AS CHAR), n.canal_n, '∅'),
           COALESCE(CAST(n.status_id_n AS CHAR), n.status_n, '∅'),
           COALESCE(n.locale_n, '∅')), 256) AS payload_hash
  FROM etl_csv_normalizada n
),
grupos AS (
  SELECT pedido_ref_n, item_seq_n,
         COUNT(DISTINCT payload_hash) AS variantes
  FROM payload
  WHERE pedido_ref_n IS NOT NULL AND item_seq_n IS NOT NULL
  GROUP BY pedido_ref_n, item_seq_n
),
ranqueados AS (
  SELECT p.*,
         ROW_NUMBER() OVER (
           PARTITION BY
             CASE WHEN p.pedido_ref_n IS NOT NULL AND p.item_seq_n IS NOT NULL
                  THEN p.pedido_ref_n END,
             CASE WHEN p.pedido_ref_n IS NOT NULL AND p.item_seq_n IS NOT NULL
                  THEN p.item_seq_n END,
             CASE WHEN p.pedido_ref_n IS NOT NULL AND p.item_seq_n IS NOT NULL
                  THEN p.payload_hash
                  ELSE CONCAT(p.payload_hash, ':', p.source_row_id) END
           ORDER BY p.source_row_id
         ) AS duplicata_ordem
  FROM payload p
)
SELECT r.*,
       COALESCE(g.variantes, 1) AS variantes_chave,
       CASE
         WHEN r.pedido_ref_n IS NULL OR r.item_seq_n IS NULL OR r.item_seq_n = 0
           OR r.data_venda_n IS NULL OR r.sku_n IS NULL OR r.produto_id IS NULL
           OR r.quantidade_n IS NULL OR r.quantidade_n <= 0 OR r.preco_n IS NULL
           OR r.moeda_valida IS NULL OR r.funcionario_id IS NULL
           OR r.canal_id_n IS NULL OR r.status_id_n IS NULL
           OR COALESCE(g.variantes, 1) > 1 OR r.duplicata_ordem > 1
           THEN 0
         ELSE 1
       END AS linha_base_valida
FROM ranqueados r
LEFT JOIN grupos g
  ON g.pedido_ref_n = r.pedido_ref_n
 AND g.item_seq_n = r.item_seq_n;

-- Cabeçalho de um pedido precisa ser consistente entre suas linhas aproveitáveis.
DROP TEMPORARY TABLE IF EXISTS etl_csv_cabecalhos;
CREATE TEMPORARY TABLE etl_csv_cabecalhos AS
SELECT pedido_ref_n,
       COUNT(DISTINCT SHA2(CONCAT_WS(CHAR(31),
         COALESCE(CAST(data_venda_n AS CHAR), '∅'),
         COALESCE(CAST(funcionario_id AS CHAR), '∅'),
         COALESCE(CAST(canal_id_n AS CHAR), '∅'),
         COALESCE(CAST(status_id_n AS CHAR), '∅')), 256)) AS variantes_cabecalho
FROM etl_csv_base
WHERE linha_base_valida = 1
GROUP BY pedido_ref_n;

DROP TEMPORARY TABLE IF EXISTS etl_csv_avaliacao;
CREATE TEMPORARY TABLE etl_csv_avaliacao AS
SELECT b.*,
       COALESCE(h.variantes_cabecalho, 1) AS variantes_cabecalho,
       CASE WHEN b.linha_base_valida = 1
                  AND COALESCE(h.variantes_cabecalho, 1) = 1
            THEN 1 ELSE 0 END AS linha_aceita
FROM etl_csv_base b
LEFT JOIN etl_csv_cabecalhos h ON h.pedido_ref_n = b.pedido_ref_n;

-- Inspeção antes do carregamento.
SELECT CASE WHEN linha_aceita = 1 THEN 'CARREGÁVEL' ELSE 'REVISAR/REJEITAR' END AS decisao,
       COUNT(*) AS linhas
FROM etl_csv_avaliacao
GROUP BY linha_aceita
ORDER BY linha_aceita DESC;

SELECT source_row_id, lote_origem, pedido_ref, item_seq,
       data_venda_raw, locale_origem, sku_raw, quantidade_raw,
       preco_unitario_raw, moeda_raw, email_vendedor_raw, canal_raw, status_raw,
       produto_id, funcionario_id, data_venda_n, quantidade_n, preco_n,
       moeda_valida, canal_id_n, status_id_n, variantes_chave,
       duplicata_ordem, variantes_cabecalho, linha_aceita
FROM etl_csv_avaliacao
ORDER BY source_row_id;

-- 3. Registra uma rejeição/revisão por campo e motivo; duplicatas usam ação DUPLICATA.
DROP TEMPORARY TABLE IF EXISTS etl_csv_problemas;
CREATE TEMPORARY TABLE etl_csv_problemas AS
SELECT source_row_id, 'pedido_ref/item_seq' AS campo,
       CONCAT(COALESCE(pedido_ref, ''), '/', COALESCE(item_seq, '')) AS valor_original,
       'Linha idêntica anterior na mesma chave pedido/item.' AS motivo,
       'DUPLICATA' AS acao
FROM etl_csv_avaliacao
WHERE duplicata_ordem > 1
UNION ALL
SELECT source_row_id, 'pedido_ref/item_seq', CONCAT(COALESCE(pedido_ref, ''), '/', COALESCE(item_seq, '')),
       'A mesma chave pedido/item tem valores normalizados conflitantes; revisar o grupo.',
       'REVISAR'
FROM etl_csv_avaliacao
WHERE variantes_chave > 1 AND duplicata_ordem = 1
UNION ALL
SELECT source_row_id, 'pedido_ref', pedido_ref, 'Referência de pedido ausente.', 'REJEITAR'
FROM etl_csv_avaliacao WHERE pedido_ref_n IS NULL
UNION ALL
SELECT source_row_id, 'item_seq', item_seq, 'Número do item ausente, não inteiro positivo ou inválido.', 'REJEITAR'
FROM etl_csv_avaliacao WHERE item_seq_n IS NULL OR item_seq_n = 0
UNION ALL
SELECT source_row_id, 'data_venda_raw', data_venda_raw,
       'Data inválida ou locale não identificado; não foi feita interpretação por palpite.',
       'REVISAR'
FROM etl_csv_avaliacao WHERE data_venda_n IS NULL
UNION ALL
SELECT source_row_id, 'sku_raw', sku_raw, 'SKU vazio ou sem correspondência no catálogo.', 'REVISAR'
FROM etl_csv_avaliacao WHERE produto_id IS NULL
UNION ALL
SELECT source_row_id, 'quantidade_raw', quantidade_raw,
       'Quantidade deve ser um inteiro positivo.', 'REJEITAR'
FROM etl_csv_avaliacao WHERE quantidade_n IS NULL OR quantidade_n <= 0
UNION ALL
SELECT source_row_id, 'preco_unitario_raw', preco_unitario_raw,
       'Preço não interpretável no locale informado.', 'REVISAR'
FROM etl_csv_avaliacao WHERE preco_n IS NULL
UNION ALL
SELECT source_row_id, 'moeda_raw', moeda_raw,
       'Moeda ausente ou fora da lista de códigos reconhecidos.', 'REVISAR'
FROM etl_csv_avaliacao WHERE moeda_valida IS NULL
UNION ALL
SELECT source_row_id, 'email_vendedor_raw', email_vendedor_raw,
       'E-mail vazio ou sem correspondência em funcionarios.', 'REVISAR'
FROM etl_csv_avaliacao WHERE funcionario_id IS NULL
UNION ALL
SELECT source_row_id, 'canal_raw', canal_raw, 'Canal sem mapeamento aprovado.', 'REVISAR'
FROM etl_csv_avaliacao WHERE canal_id_n IS NULL
UNION ALL
SELECT source_row_id, 'status_raw', status_raw,
       'Status sem mapeamento; status pendente não existe no domínio atual.', 'REVISAR'
FROM etl_csv_avaliacao WHERE status_id_n IS NULL
UNION ALL
SELECT a.source_row_id, 'pedido_ref', a.pedido_ref,
       'As linhas válidas do pedido discordam em data, vendedor, canal ou status.',
       'REVISAR'
FROM etl_csv_avaliacao a
JOIN etl_csv_cabecalhos h ON h.pedido_ref_n = a.pedido_ref_n
WHERE h.variantes_cabecalho > 1 AND a.linha_base_valida = 1;

-- Em uma carga repetida, não repete exatamente o mesmo evento de rejeição.
DROP TEMPORARY TABLE IF EXISTS etl_csv_problemas_novos;
CREATE TEMPORARY TABLE etl_csv_problemas_novos AS
SELECT p.*
FROM etl_csv_problemas p
WHERE NOT EXISTS (
  SELECT 1
  FROM etl_rejeicoes er
  JOIN acoes_etl ae ON ae.acao_etl_id = er.acao_etl_id
  WHERE er.source_row_id = p.source_row_id
    AND er.campo = p.campo
    AND er.motivo = p.motivo
    AND ae.nome = p.acao
);

START TRANSACTION;

INSERT INTO etl_rejeicoes
  (rejeicao_id, source_row_id, campo, valor_original, motivo, acao_etl_id)
SELECT (SELECT COALESCE(MAX(rejeicao_id), 0) FROM etl_rejeicoes)
         + ROW_NUMBER() OVER (ORDER BY p.source_row_id, p.campo, p.motivo),
       p.source_row_id, p.campo, LEFT(p.valor_original, 128), p.motivo, a.acao_etl_id
FROM etl_csv_problemas_novos p
JOIN acoes_etl a ON a.nome = p.acao;

-- 4. Cria apenas um cabeçalho por pedido entre as linhas aceitas.
DROP TEMPORARY TABLE IF EXISTS etl_csv_pedidos_validos;
CREATE TEMPORARY TABLE etl_csv_pedidos_validos AS
SELECT pedido_ref_n AS referencia_origem,
       MIN(data_venda_n) AS data_venda,
       MIN(funcionario_id) AS funcionario_id,
       MIN(canal_id_n) AS canal_venda_id,
       MIN(status_id_n) AS status_venda_id
FROM etl_csv_avaliacao
WHERE linha_aceita = 1
GROUP BY pedido_ref_n
HAVING COUNT(DISTINCT SHA2(CONCAT_WS(CHAR(31),
         COALESCE(CAST(data_venda_n AS CHAR), '∅'),
         COALESCE(CAST(funcionario_id AS CHAR), '∅'),
         COALESCE(CAST(canal_id_n AS CHAR), '∅'),
         COALESCE(CAST(status_id_n AS CHAR), '∅')), 256)) = 1;

DROP TEMPORARY TABLE IF EXISTS etl_csv_novas_vendas;
CREATE TEMPORARY TABLE etl_csv_novas_vendas AS
SELECT (SELECT COALESCE(MAX(venda_id), 0) FROM vendas)
         + ROW_NUMBER() OVER (ORDER BY p.referencia_origem) AS venda_id,
       p.*
FROM etl_csv_pedidos_validos p
WHERE NOT EXISTS (
  SELECT 1 FROM vendas v WHERE v.referencia_origem = p.referencia_origem
);

INSERT INTO vendas
  (venda_id, referencia_origem, data_venda, funcionario_id, canal_venda_id, status_venda_id)
SELECT venda_id, referencia_origem, data_venda, funcionario_id, canal_venda_id, status_venda_id
FROM etl_csv_novas_vendas;

-- 5. Carrega itens; source_row_id garante rastreabilidade e impede reimportação da linha.
DROP TEMPORARY TABLE IF EXISTS etl_csv_itens_validos;
CREATE TEMPORARY TABLE etl_csv_itens_validos AS
SELECT a.source_row_id, v.venda_id, a.item_seq_n AS numero_item,
       a.produto_id, a.quantidade_n AS quantidade, a.preco_n AS preco_unitario,
       a.moeda_valida AS moeda
FROM etl_csv_avaliacao a
JOIN vendas v ON v.referencia_origem = a.pedido_ref_n
WHERE a.linha_aceita = 1
  AND NOT EXISTS (
    SELECT 1 FROM itens_venda i WHERE i.source_row_id = a.source_row_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM itens_venda i
    WHERE i.venda_id = v.venda_id AND i.numero_item = a.item_seq_n
  );

INSERT INTO itens_venda
  (item_venda_id, venda_id, numero_item, produto_id, quantidade,
   preco_unitario, moeda, source_row_id)
SELECT (SELECT COALESCE(MAX(item_venda_id), 0) FROM itens_venda)
         + ROW_NUMBER() OVER (ORDER BY l.source_row_id),
       l.venda_id, l.numero_item, l.produto_id, l.quantidade,
       l.preco_unitario, l.moeda, l.source_row_id
FROM etl_csv_itens_validos l;

COMMIT;

-- Conferência pós-carga: registros por pedido/moeda e rejeições por ação.
SELECT v.referencia_origem, sv.nome AS status_venda, i.moeda,
       COUNT(*) AS itens, SUM(i.quantidade) AS unidades,
       SUM(i.quantidade * i.preco_unitario) AS valor
FROM vendas v
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
JOIN itens_venda i ON i.venda_id = v.venda_id
JOIN stg_vendas_csv s ON s.source_row_id = i.source_row_id
GROUP BY v.referencia_origem, sv.nome, i.moeda
ORDER BY v.referencia_origem, i.moeda;

SELECT ae.nome AS acao_etl, er.campo, er.motivo, COUNT(*) AS linhas
FROM etl_rejeicoes er
JOIN acoes_etl ae ON ae.acao_etl_id = er.acao_etl_id
JOIN stg_vendas_csv s ON s.source_row_id = er.source_row_id
GROUP BY ae.nome, er.campo, er.motivo
ORDER BY ae.nome, er.campo;

-- Observações para o CSV fornecido:
-- * source_row_id 3 repete a linha 1; source_row_id 13 conflita com a mesma chave
--   EXT-9001/item 1. As linhas 1 e 13 ficam para revisão; a linha 3 é registrada
--   como duplicata. A linha 2 do pedido pode ser carregada pela política parcial.
-- * locale '?' (linha 5), data impossível (linha 6), SKU/vendedor desconhecidos,
--   quantidade inválida, preço inválido, moeda ausente/não reconhecida, canal
--   TikTok Shop sem mapeamento e status pending ficam documentados para revisão.
-- * O mapeamento de números assume ponto decimal para ISO/en-US e vírgula decimal
--   para pt-BR. Confirme essa convenção com o dono do arquivo antes de ampliar o uso.
-- * A geração de IDs por MAX + ROW_NUMBER pressupõe uma única sessão ETL por vez.
