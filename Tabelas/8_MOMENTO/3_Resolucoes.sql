-- Gabarito de consultas dos níveis 0 a 10 do README.
-- MySQL 8.0+. Este arquivo contém consultas de leitura; não altera os dados.
USE momento;

-- ETAPA 0 — EXPLORAR
-- Visão geral da quantidade de registros nas tabelas principais.
SELECT 'funcionarios' AS tabela, COUNT(*) AS registros FROM funcionarios
UNION ALL SELECT 'departamentos', COUNT(*) FROM departamentos
UNION ALL SELECT 'escritorios', COUNT(*) FROM escritorios
UNION ALL SELECT 'produtos', COUNT(*) FROM produtos
UNION ALL SELECT 'vendas', COUNT(*) FROM vendas
UNION ALL SELECT 'itens_venda', COUNT(*) FROM itens_venda
UNION ALL SELECT 'alunos', COUNT(*) FROM alunos
UNION ALL SELECT 'matriculas', COUNT(*) FROM matriculas;

-- Valores distintos ajudam a entender domínios, moedas e nulos antes das análises.
SELECT moeda_salario AS moeda, COUNT(*) AS funcionarios
FROM funcionarios
GROUP BY moeda_salario
ORDER BY moeda_salario;

SELECT nome AS status_funcionario, COUNT(*) AS quantidade
FROM funcionarios f
JOIN status_funcionario sf USING (status_funcionario_id)
GROUP BY nome
ORDER BY nome;

-- NÍVEL 1 — CONHECENDO A EMPRESA
-- 1.1: preencha os valores com seus próprios dados antes de executar.
-- O exemplo escolhe o departamento de Tecnologia da Informação (id 6) e um cargo
-- existente. Confira primeiro os cargos e a faixa salarial:
SELECT cargo_id, cargo_nome, min_salario, max_salario
FROM cargos
ORDER BY cargo_nome;
-- Modelo de INSERT (substitua os textos entre < > e escolha um salário válido):
-- INSERT INTO funcionarios
--   (funcionario_id, primeiro_nome, sobrenome, email, telefone, data_contratacao,
--    cargo_id, salario, moeda_salario, gerente_id, departamento_id, status_funcionario_id)
-- SELECT COALESCE(MAX(funcionario_id), 0) + 1,
--        '<SEU_PRIMEIRO_NOME>', '<SEU_SOBRENOME>', '<SEU_EMAIL_UNICO>',
--        NULL, CURRENT_DATE, <CARGO_ID_EXISTENTE>, <SALARIO>, 'USD',
--        NULL, 6, 1
-- FROM funcionarios;

-- 1.2: total cadastrado; execute após o INSERT de 1.1 se quiser incluir seu registro.
SELECT COUNT(*) AS total_funcionarios FROM funcionarios;

-- 1.3: departamento chamado Tecnologia da Informação na base atual.
SELECT d.departamento_nome, COUNT(f.funcionario_id) AS total_funcionarios
FROM departamentos d
LEFT JOIN funcionarios f ON f.departamento_id = d.departamento_id
WHERE d.departamento_nome = 'Tecnologia da Informação'
GROUP BY d.departamento_id, d.departamento_nome;

-- 1.4: lista e total de departamentos.
SELECT d.departamento_id, d.departamento_nome, d.educacional, e.escritorio_nome
FROM departamentos d
JOIN escritorios e ON e.escritorio_id = d.escritorio_id
ORDER BY d.departamento_nome, e.escritorio_nome;
SELECT COUNT(*) AS total_departamentos FROM departamentos;

-- 1.5: quantidade de escritórios e países em que estão.
SELECT COUNT(*) AS total_escritorios,
       COUNT(DISTINCT e.pais_id) AS total_paises
FROM escritorios e;
SELECT p.pais_nome, COUNT(*) AS total_escritorios
FROM escritorios e
JOIN paises p ON p.pais_id = e.pais_id
GROUP BY p.pais_id, p.pais_nome
ORDER BY p.pais_nome;

-- NÍVEL 2 — ANÁLISE FINANCEIRA BÁSICA
-- Os salários estão em moedas diferentes; mantenha a moeda no agrupamento.
-- 2.1 e 2.2
SELECT d.departamento_nome, f.moeda_salario,
       COUNT(f.funcionario_id) AS total_funcionarios,
       COALESCE(SUM(f.salario), 0) AS custo_total_salarios
FROM departamentos d
LEFT JOIN funcionarios f ON f.departamento_id = d.departamento_id
WHERE d.departamento_nome = 'Vendas'
GROUP BY d.departamento_id, d.departamento_nome, f.moeda_salario;

-- 2.3: médias sem CEO, CMO e CFO, separadas por moeda.
SELECT f.moeda_salario,
       ROUND(AVG(f.salario), 2) AS salario_medio
FROM funcionarios f
JOIN cargos c ON c.cargo_id = f.cargo_id
WHERE c.cargo_nome NOT IN ('CEO', 'CMO', 'CFO')
GROUP BY f.moeda_salario
ORDER BY f.moeda_salario;

-- 2.4
SELECT d.departamento_nome, f.moeda_salario,
       ROUND(AVG(f.salario), 2) AS salario_medio
FROM funcionarios f
JOIN departamentos d ON d.departamento_id = f.departamento_id
WHERE d.departamento_nome = 'Tecnologia da Informação'
GROUP BY d.departamento_id, d.departamento_nome, f.moeda_salario;

-- 2.5: departamento(s) com a maior média dentro de cada moeda.
WITH medias AS (
  SELECT d.departamento_id, d.departamento_nome, f.moeda_salario,
         AVG(f.salario) AS media_salarial
  FROM departamentos d
  JOIN funcionarios f ON f.departamento_id = d.departamento_id
  GROUP BY d.departamento_id, d.departamento_nome, f.moeda_salario
)
SELECT departamento_nome, moeda_salario, ROUND(media_salarial, 2) AS media_salarial
FROM medias m
WHERE media_salarial = (
  SELECT MAX(m2.media_salarial)
  FROM medias m2
  WHERE m2.moeda_salario = m.moeda_salario
)
ORDER BY moeda_salario, departamento_nome;

-- 2.6: inclui departamentos vazios.
SELECT d.departamento_nome, COUNT(f.funcionario_id) AS total_funcionarios
FROM departamentos d
LEFT JOIN funcionarios f ON f.departamento_id = d.departamento_id
GROUP BY d.departamento_id, d.departamento_nome
ORDER BY total_funcionarios, d.departamento_nome;

-- NÍVEL 3 — RECURSOS HUMANOS
-- 3.1: COUNT DISTINCT evita contar duas vezes uma pessoa com mais de um cônjuge registrado.
SELECT COUNT(DISTINCT d.funcionario_id) AS funcionarios_com_conjuge
FROM dependentes d
WHERE LOWER(d.relacionamento) LIKE '%cônjuge%'
   OR LOWER(d.relacionamento) LIKE '%conjuge%';

-- 3.2: filhos registrados.
SELECT COUNT(DISTINCT d.funcionario_id) AS funcionarios_com_filhos
FROM dependentes d
WHERE LOWER(d.relacionamento) LIKE '%filh%';

-- 3.3
SELECT funcionario_id, primeiro_nome, sobrenome, data_contratacao
FROM funcionarios
WHERE data_contratacao = (SELECT MIN(data_contratacao) FROM funcionarios)
ORDER BY funcionario_id;

-- 3.4
SELECT funcionario_id, primeiro_nome, sobrenome, data_contratacao
FROM funcionarios
WHERE data_contratacao = (SELECT MAX(data_contratacao) FROM funcionarios)
ORDER BY funcionario_id;

-- 3.5
SELECT funcionario_id, primeiro_nome, sobrenome, data_contratacao
FROM funcionarios
ORDER BY data_contratacao, funcionario_id
LIMIT 5;

-- 3.6: intervalo semiaberto cobre todos os dias de 1990 a 1999.
SELECT COUNT(*) AS contratados_na_decada_1990
FROM funcionarios
WHERE data_contratacao >= '1990-01-01'
  AND data_contratacao <  '2000-01-01';

-- 3.7: médias anuais sem misturar moedas.
SELECT YEAR(data_contratacao) AS ano_contratacao, moeda_salario,
       COUNT(*) AS contratacoes,
       ROUND(AVG(salario), 2) AS salario_medio
FROM funcionarios
GROUP BY YEAR(data_contratacao), moeda_salario
ORDER BY ano_contratacao, moeda_salario;

-- NÍVEL 4 — OPERAÇÕES E ESCRITÓRIOS
-- 4.1: custo de estoque = quantidade × custo unitário; resultado separado por moeda.
SELECT e.escritorio_nome, s.moeda,
       SUM(s.quantidade_estoque * s.custo_unitario) AS custo_total_suprimentos
FROM escritorios e
JOIN suprimentos s ON s.escritorio_id = e.escritorio_id
GROUP BY e.escritorio_id, e.escritorio_nome, s.moeda
ORDER BY custo_total_suprimentos DESC;

-- 4.2
SELECT e.escritorio_nome, COUNT(DISTINCT s.suprimento_nome) AS tipos_suprimento
FROM escritorios e
LEFT JOIN suprimentos s ON s.escritorio_id = e.escritorio_id
GROUP BY e.escritorio_id, e.escritorio_nome
ORDER BY tipos_suprimento DESC, e.escritorio_nome;

-- 4.3: compara preço unitário apenas dentro da mesma moeda.
WITH precos AS (
  SELECT s.*, MAX(s.custo_unitario) OVER (PARTITION BY s.moeda) AS maior_preco_moeda
  FROM suprimentos s
)
SELECT e.escritorio_nome, p.suprimento_nome, p.custo_unitario, p.moeda
FROM precos p
JOIN escritorios e ON e.escritorio_id = p.escritorio_id
WHERE p.custo_unitario = p.maior_preco_moeda
ORDER BY p.moeda, e.escritorio_nome, p.suprimento_nome;

-- 4.4: valor do inventário por moeda; não há taxa de câmbio no modelo.
SELECT moeda,
       SUM(quantidade_estoque * custo_unitario) AS valor_total_inventario
FROM suprimentos
GROUP BY moeda
ORDER BY moeda;

-- NÍVEL 5 — PRODUTOS E VENDAS
-- Receita e ranking consideram vendas concluídas e o preço histórico do item.
-- 5.1
SELECT DISTINCT p.produto_id, p.sku, p.produto_nome
FROM produtos p
JOIN itens_venda i ON i.produto_id = p.produto_id
JOIN vendas v ON v.venda_id = i.venda_id
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
WHERE sv.nome = 'CONCLUIDA'
ORDER BY p.produto_nome;

-- 5.2: retorna empates.
WITH unidades AS (
  SELECT p.produto_id, p.sku, p.produto_nome,
         SUM(i.quantidade) AS unidades_vendidas
  FROM produtos p
  JOIN itens_venda i ON i.produto_id = p.produto_id
  JOIN vendas v ON v.venda_id = i.venda_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY p.produto_id, p.sku, p.produto_nome
)
SELECT produto_id, sku, produto_nome, unidades_vendidas
FROM unidades
WHERE unidades_vendidas = (SELECT MAX(unidades_vendidas) FROM unidades);

-- 5.3: menor quantidade entre produtos que efetivamente tiveram venda concluída.
WITH unidades AS (
  SELECT p.produto_id, p.sku, p.produto_nome,
         SUM(i.quantidade) AS unidades_vendidas
  FROM produtos p
  JOIN itens_venda i ON i.produto_id = p.produto_id
  JOIN vendas v ON v.venda_id = i.venda_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY p.produto_id, p.sku, p.produto_nome
)
SELECT produto_id, sku, produto_nome, unidades_vendidas
FROM unidades
WHERE unidades_vendidas = (SELECT MIN(unidades_vendidas) FROM unidades);

-- 5.4: maior receita em cada moeda; moedas diferentes não são comparáveis sem câmbio.
WITH receitas AS (
  SELECT p.produto_id, p.sku, p.produto_nome, i.moeda,
         SUM(i.quantidade * i.preco_unitario) AS receita
  FROM produtos p
  JOIN itens_venda i ON i.produto_id = p.produto_id
  JOIN vendas v ON v.venda_id = i.venda_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY p.produto_id, p.sku, p.produto_nome, i.moeda
),
ordenadas AS (
  SELECT receitas.*,
         RANK() OVER (PARTITION BY moeda ORDER BY receita DESC) AS posicao
  FROM receitas
)
SELECT produto_id, sku, produto_nome, moeda, receita
FROM ordenadas
WHERE posicao = 1
ORDER BY moeda, produto_nome;

-- 5.5: produto(s) mais caro(s) do catálogo em cada moeda.
WITH catalogo AS (
  SELECT p.*, MAX(preco_catalogo) OVER (PARTITION BY moeda) AS max_preco_moeda
  FROM produtos p
)
SELECT produto_id, sku, produto_nome, preco_catalogo, moeda
FROM catalogo
WHERE preco_catalogo = max_preco_moeda
ORDER BY moeda, produto_nome;

-- 5.6: faturamento concluído por moeda; não converte BRL, USD ou GBP entre si.
SELECT i.moeda,
       SUM(i.quantidade * i.preco_unitario) AS faturamento
FROM vendas v
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
JOIN itens_venda i ON i.venda_id = v.venda_id
WHERE sv.nome = 'CONCLUIDA'
GROUP BY i.moeda
ORDER BY i.moeda;

-- 5.7
SELECT COUNT(DISTINCT v.venda_id) AS vendas_junho_2023
FROM vendas v
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
WHERE sv.nome = 'CONCLUIDA'
  AND v.data_venda >= '2023-06-01'
  AND v.data_venda <  '2023-07-01';

-- 5.8: mais transações concluídas por vendedor; retorna empates.
WITH desempenho AS (
  SELECT f.funcionario_id, f.primeiro_nome, f.sobrenome,
         COUNT(DISTINCT v.venda_id) AS total_vendas
  FROM funcionarios f
  JOIN vendas v ON v.funcionario_id = f.funcionario_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY f.funcionario_id, f.primeiro_nome, f.sobrenome
)
SELECT *
FROM desempenho
WHERE total_vendas = (SELECT MAX(total_vendas) FROM desempenho);

-- 5.9: vendedores com maior receita por moeda; retorna empates.
WITH receita AS (
  SELECT f.funcionario_id, f.primeiro_nome, f.sobrenome, i.moeda,
         SUM(i.quantidade * i.preco_unitario) AS receita_total
  FROM funcionarios f
  JOIN vendas v ON v.funcionario_id = f.funcionario_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  JOIN itens_venda i ON i.venda_id = v.venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY f.funcionario_id, f.primeiro_nome, f.sobrenome, i.moeda
)
SELECT *
FROM receita r
WHERE receita_total = (
  SELECT MAX(r2.receita_total)
  FROM receita r2
  WHERE r2.moeda = r.moeda
)
ORDER BY moeda;

-- NÍVEL 6 — OPERAÇÕES DE ATUALIZAÇÃO
-- As alterações estão no arquivo 5_Alteracoes_Seguras.sql e terminam em ROLLBACK.
-- 6.6: prévia dos funcionários contratados antes de 1990. Não execute DELETE.
SELECT funcionario_id, primeiro_nome, sobrenome, data_contratacao,
       departamento_id, status_funcionario_id
FROM funcionarios
WHERE data_contratacao < '1990-01-01'
ORDER BY data_contratacao;
SELECT COUNT(*) AS pessoas_na_previa
FROM funcionarios
WHERE data_contratacao < '1990-01-01';

-- NÍVEL 7 — DA SALA DE AULA AO IMPACTO CORPORATIVO
-- 7.1
SELECT c.curso_id, c.curso_nome, c.carga_horaria, nc.nome AS nivel,
       COUNT(DISTINCT t.turma_id) AS turmas_abertas
FROM cursos c
JOIN niveis_curso nc ON nc.nivel_curso_id = c.nivel_curso_id
LEFT JOIN turmas t ON t.curso_id = c.curso_id
WHERE c.ativo = TRUE
GROUP BY c.curso_id, c.curso_nome, c.carga_horaria, nc.nome
ORDER BY c.curso_nome;

-- 7.2
SELECT c.curso_nome, t.turma_id, t.codigo AS turma,
       CONCAT(f.primeiro_nome, ' ', f.sobrenome) AS professor,
       t.capacidade, COUNT(DISTINCT m.matricula_id) AS matriculas
FROM turmas t
JOIN cursos c ON c.curso_id = t.curso_id
JOIN funcionarios f ON f.funcionario_id = t.professor_funcionario_id
LEFT JOIN matriculas m ON m.turma_id = t.turma_id
GROUP BY c.curso_nome, t.turma_id, t.codigo, f.funcionario_id,
         f.primeiro_nome, f.sobrenome, t.capacidade
ORDER BY c.curso_nome, t.codigo;

-- 7.3: bolsas concedidas e percentual médio por curso. A contagem de alunos é distinta.
SELECT c.curso_nome,
       COUNT(b.bolsa_id) AS bolsas_concedidas,
       COUNT(DISTINCT b.aluno_id) AS estudantes_beneficiados,
       ROUND(AVG(b.percentual_desconto), 2) AS percentual_medio,
       MIN(b.percentual_desconto) AS menor_percentual,
       MAX(b.percentual_desconto) AS maior_percentual
FROM cursos c
LEFT JOIN bolsas b ON b.curso_id = c.curso_id
GROUP BY c.curso_id, c.curso_nome
ORDER BY c.curso_nome;

-- 7.4: contar matrículas antes de juntar bolsas/vínculos evita multiplicação de linhas.
SELECT c.curso_nome, t.codigo AS turma,
       COUNT(m.matricula_id) AS matriculas,
       SUM(CASE WHEN sm.nome = 'CONCLUIDA' THEN 1 ELSE 0 END) AS concluintes,
       SUM(CASE WHEN m.certificado_emitido = TRUE THEN 1 ELSE 0 END) AS certificados_emitidos,
       ROUND(AVG(m.nota_final), 2) AS nota_media
FROM cursos c
JOIN turmas t ON t.curso_id = c.curso_id
LEFT JOIN matriculas m ON m.turma_id = t.turma_id
LEFT JOIN status_matricula sm ON sm.status_matricula_id = m.status_matricula_id
GROUP BY c.curso_id, c.curso_nome, t.turma_id, t.codigo
ORDER BY c.curso_nome, t.codigo;
-- Comparações de sucesso também exigem contexto: período, perfil e tamanho das turmas,
-- critérios de conclusão, evasão, acesso, custos, objetivos do curso e qualidade das notas.

-- 7.5: linha do tempo de Ariel Nunes, unindo formação, bolsa e vínculos corporativos.
SELECT evento, data_evento, detalhe
FROM (
  SELECT 'MATRÍCULA' AS evento, m.data_matricula AS data_evento,
         CONCAT(c.curso_nome, ' / ', t.codigo, ' / status: ', sm.nome) AS detalhe
  FROM alunos a
  JOIN matriculas m ON m.aluno_id = a.aluno_id
  JOIN turmas t ON t.turma_id = m.turma_id
  JOIN cursos c ON c.curso_id = t.curso_id
  JOIN status_matricula sm ON sm.status_matricula_id = m.status_matricula_id
  WHERE a.nome = 'Ariel Nunes'
  UNION ALL
  SELECT 'BOLSA', b.data_concessao,
         CONCAT(c.curso_nome, ' / desconto: ', b.percentual_desconto, '%')
  FROM alunos a
  JOIN bolsas b ON b.aluno_id = a.aluno_id
  JOIN cursos c ON c.curso_id = b.curso_id
  WHERE a.nome = 'Ariel Nunes'
  UNION ALL
  SELECT tv.nome, vt.data_inicio,
         CONCAT(d.departamento_nome, ' / status: ', sv.nome)
  FROM alunos a
  JOIN vinculos_talentos vt ON vt.aluno_id = a.aluno_id
  JOIN tipos_vinculo tv ON tv.tipo_vinculo_id = vt.tipo_vinculo_id
  JOIN status_vinculo sv ON sv.status_vinculo_id = vt.status_vinculo_id
  JOIN departamentos d ON d.departamento_id = vt.departamento_id
  WHERE a.nome = 'Ariel Nunes'
) linha_do_tempo
ORDER BY data_evento, evento;
-- Na carga demonstrativa, o vínculo de estágio começa em 2025-05-05 e a contratação
-- em 2025-05-12, após a matrícula e a conclusão do curso.

-- 7.6
SELECT a.nome AS estudante, tv.nome AS tipo_vinculo,
       d.departamento_nome, sv.nome AS status_vinculo,
       CONCAT(f.primeiro_nome, ' ', f.sobrenome) AS funcionario_associado,
       vt.data_inicio, vt.data_fim
FROM vinculos_talentos vt
JOIN alunos a ON a.aluno_id = vt.aluno_id
JOIN tipos_vinculo tv ON tv.tipo_vinculo_id = vt.tipo_vinculo_id
JOIN departamentos d ON d.departamento_id = vt.departamento_id
JOIN status_vinculo sv ON sv.status_vinculo_id = vt.status_vinculo_id
LEFT JOIN funcionarios f ON f.funcionario_id = vt.funcionario_id
ORDER BY a.nome, vt.data_inicio;
SELECT tv.nome AS tipo_vinculo,
       COUNT(DISTINCT vt.aluno_id) AS pessoas
FROM vinculos_talentos vt
JOIN tipos_vinculo tv ON tv.tipo_vinculo_id = vt.tipo_vinculo_id
GROUP BY tv.tipo_vinculo_id, tv.nome
ORDER BY tv.nome;

-- 7.7
SELECT DISTINCT d.departamento_id, d.departamento_nome
FROM vinculos_talentos vt
JOIN departamentos d ON d.departamento_id = vt.departamento_id
ORDER BY d.departamento_nome;

-- 7.8: um único SELECT, com subconsultas escalares para não multiplicar contagens.
SELECT
  (SELECT COUNT(*) FROM alunos) AS total_alunos,
  (SELECT COUNT(*)
   FROM matriculas m JOIN status_matricula sm USING (status_matricula_id)
   WHERE sm.nome = 'ATIVA') AS matriculas_ativas,
  (SELECT COUNT(*)
   FROM matriculas m JOIN status_matricula sm USING (status_matricula_id)
   WHERE sm.nome = 'CONCLUIDA') AS concluintes,
  (SELECT COUNT(*) FROM bolsas) AS bolsas_concedidas,
  (SELECT COUNT(DISTINCT vt.aluno_id)
   FROM vinculos_talentos vt JOIN tipos_vinculo tv USING (tipo_vinculo_id)
   WHERE tv.nome = 'ESTAGIO') AS pessoas_que_estagiaram,
  (SELECT COUNT(DISTINCT vt.aluno_id)
   FROM vinculos_talentos vt JOIN tipos_vinculo tv USING (tipo_vinculo_id)
   WHERE tv.nome = 'CONTRATACAO') AS pessoas_contratadas,
  (SELECT GROUP_CONCAT(DISTINCT d.departamento_nome ORDER BY d.departamento_nome SEPARATOR ', ')
   FROM vinculos_talentos vt JOIN departamentos d USING (departamento_id))
     AS departamentos_que_receberam_talentos;

-- 7.11: vinculos_talentos registra a passagem de alunos para oportunidades da empresa.
-- O aluno e o departamento são obrigatórios; funcionário associado e data_fim são opcionais.
SELECT vt.vinculo_id, a.nome, tv.nome AS tipo_vinculo, d.departamento_nome,
       sv.nome AS status_vinculo, vt.data_inicio, vt.data_fim,
       vt.funcionario_id
FROM vinculos_talentos vt
JOIN alunos a USING (aluno_id)
JOIN tipos_vinculo tv USING (tipo_vinculo_id)
JOIN departamentos d USING (departamento_id)
JOIN status_vinculo sv USING (status_vinculo_id)
ORDER BY vt.data_inicio, vt.vinculo_id;

-- NÍVEL 8 — DUAS FRENTES, DUAS OPERAÇÕES
-- 8.1: salários por departamento/moeda.
SELECT d.departamento_nome, d.educacional, f.moeda_salario AS moeda,
       COUNT(f.funcionario_id) AS funcionarios,
       COALESCE(SUM(f.salario), 0) AS custo_salarial
FROM departamentos d
LEFT JOIN funcionarios f ON f.departamento_id = d.departamento_id
GROUP BY d.departamento_id, d.departamento_nome, d.educacional, f.moeda_salario
ORDER BY d.educacional DESC, d.departamento_nome, moeda;
-- Suprimentos pertencem a escritórios, não a departamentos. Veja o custo por escritório:
SELECT d.educacional, e.escritorio_nome, s.moeda,
       SUM(s.quantidade_estoque * s.custo_unitario) AS custo_suprimentos
FROM (SELECT DISTINCT educacional, escritorio_id FROM departamentos) d
JOIN escritorios e ON e.escritorio_id = d.escritorio_id
JOIN suprimentos s ON s.escritorio_id = e.escritorio_id
GROUP BY d.educacional, e.escritorio_id, e.escritorio_nome, s.moeda
ORDER BY d.educacional DESC, e.escritorio_nome, s.moeda;
-- Não existe tabela de despesas gerais nem rateio de suprimentos por departamento.
-- Não some custo do escritório repetido por departamento como se fosse custo individual.

-- 8.2: escritórios e tamanho das equipes por frente.
SELECT e.escritorio_nome, p.pais_nome, d.educacional,
       COUNT(DISTINCT d.departamento_id) AS departamentos,
       COUNT(DISTINCT f.funcionario_id) AS funcionarios
FROM escritorios e
JOIN paises p ON p.pais_id = e.pais_id
JOIN departamentos d ON d.escritorio_id = e.escritorio_id
LEFT JOIN funcionarios f ON f.departamento_id = d.departamento_id
GROUP BY e.escritorio_id, e.escritorio_nome, p.pais_nome, d.educacional
ORDER BY e.escritorio_nome, d.educacional DESC;

-- 8.3: comparação indicativa, por moeda. Só receita concluída e custos observáveis.
WITH receita AS (
  SELECT i.moeda, SUM(i.quantidade * i.preco_unitario) AS valor
  FROM vendas v
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  JOIN itens_venda i ON i.venda_id = v.venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY i.moeda
),
folha_educacional AS (
  SELECT f.moeda_salario AS moeda, SUM(f.salario) AS valor
  FROM funcionarios f
  JOIN departamentos d ON d.departamento_id = f.departamento_id
  WHERE d.educacional = TRUE
  GROUP BY f.moeda_salario
),
suprimentos_educacionais AS (
  SELECT s.moeda, SUM(s.quantidade_estoque * s.custo_unitario) AS valor
  FROM suprimentos s
  WHERE s.escritorio_id IN (
    SELECT DISTINCT escritorio_id FROM departamentos WHERE educacional = TRUE
  )
  GROUP BY s.moeda
),
moedas AS (
  SELECT moeda FROM receita
  UNION SELECT moeda FROM folha_educacional
  UNION SELECT moeda FROM suprimentos_educacionais
)
SELECT m.moeda, COALESCE(r.valor, 0) AS receita_vendas,
       COALESCE(f.valor, 0) AS salarios_escola,
       COALESCE(s.valor, 0) AS suprimentos_escola,
       COALESCE(r.valor, 0) - COALESCE(f.valor, 0) - COALESCE(s.valor, 0)
         AS saldo_antes_despesas_gerais
FROM moedas m
LEFT JOIN receita r USING (moeda)
LEFT JOIN folha_educacional f USING (moeda)
LEFT JOIN suprimentos_educacionais s USING (moeda)
ORDER BY m.moeda;
-- O resultado não prova sustentabilidade: despesas gerais, períodos de competência,
-- câmbio e custos educacionais sem vínculo a escritório não estão modelados.

-- 8.4a: cargos encontrados nas duas frentes.
SELECT c.cargo_nome,
       COUNT(DISTINCT CASE WHEN d.educacional = FALSE THEN f.funcionario_id END)
         AS funcionarios_comerciais,
       COUNT(DISTINCT CASE WHEN d.educacional = TRUE THEN f.funcionario_id END)
         AS funcionarios_educacionais
FROM funcionarios f
JOIN cargos c ON c.cargo_id = f.cargo_id
JOIN departamentos d ON d.departamento_id = f.departamento_id
GROUP BY c.cargo_id, c.cargo_nome
HAVING funcionarios_comerciais > 0 AND funcionarios_educacionais > 0
ORDER BY c.cargo_nome;

-- 8.4b: nomes de departamentos presentes nas duas frentes, possivelmente em escritórios distintos.
SELECT d.departamento_nome,
       GROUP_CONCAT(DISTINCT CASE WHEN d.educacional THEN 'EDUCACIONAL'
                                  ELSE 'COMERCIAL' END ORDER BY d.educacional) AS frentes
FROM departamentos d
GROUP BY d.departamento_nome
HAVING COUNT(DISTINCT d.educacional) = 2
ORDER BY d.departamento_nome;

-- 8.5: indicadores por país; receita atribuída ao país do escritório do vendedor.
WITH equipes AS (
  SELECT e.pais_id,
         SUM(CASE WHEN d.educacional = FALSE THEN 1 ELSE 0 END) AS equipe_comercial,
         SUM(CASE WHEN d.educacional = TRUE THEN 1 ELSE 0 END) AS equipe_escola
  FROM funcionarios f
  JOIN departamentos d ON d.departamento_id = f.departamento_id
  JOIN escritorios e ON e.escritorio_id = d.escritorio_id
  GROUP BY e.pais_id
),
receita_pais AS (
  SELECT e.pais_id, i.moeda, SUM(i.quantidade * i.preco_unitario) AS receita
  FROM vendas v
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  JOIN itens_venda i ON i.venda_id = v.venda_id
  JOIN funcionarios f ON f.funcionario_id = v.funcionario_id
  JOIN departamentos d ON d.departamento_id = f.departamento_id
  JOIN escritorios e ON e.escritorio_id = d.escritorio_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY e.pais_id, i.moeda
),
impacto_escola AS (
  SELECT e.pais_id, COUNT(DISTINCT t.turma_id) AS turmas,
         COUNT(DISTINCT m.aluno_id) AS alunos_matriculados
  FROM turmas t
  JOIN escritorios e ON e.escritorio_id = t.escritorio_id
  LEFT JOIN matriculas m ON m.turma_id = t.turma_id
  GROUP BY e.pais_id
)
SELECT p.pais_nome, COUNT(DISTINCT e.escritorio_id) AS escritorios,
       COALESCE(eq.equipe_comercial, 0) AS equipe_comercial,
       COALESCE(eq.equipe_escola, 0) AS equipe_escola,
       COALESCE(ie.turmas, 0) AS turmas,
       COALESCE(ie.alunos_matriculados, 0) AS alunos_matriculados,
       rp.moeda, rp.receita AS receita_vendas
FROM paises p
LEFT JOIN escritorios e ON e.pais_id = p.pais_id
LEFT JOIN equipes eq ON eq.pais_id = p.pais_id
LEFT JOIN impacto_escola ie ON ie.pais_id = p.pais_id
LEFT JOIN receita_pais rp ON rp.pais_id = p.pais_id
GROUP BY p.pais_id, p.pais_nome, eq.equipe_comercial, eq.equipe_escola,
         ie.turmas, ie.alunos_matriculados, rp.moeda, rp.receita
ORDER BY p.pais_nome, rp.moeda;
-- O painel compara presença de equipes, vendas e atividade escolar; causalidade exige
-- séries históricas comparáveis e contexto sobre a data de abertura de cada escritório.

-- NÍVEL 9 — AGREGAÇÕES
-- 9.1
SELECT d.departamento_nome, COUNT(f.funcionario_id) AS total_funcionarios,
       f.moeda_salario, COALESCE(SUM(f.salario), 0) AS salario_total,
       ROUND(AVG(f.salario), 2) AS salario_medio
FROM departamentos d
LEFT JOIN funcionarios f ON f.departamento_id = d.departamento_id
GROUP BY d.departamento_id, d.departamento_nome, f.moeda_salario
ORDER BY d.departamento_nome, f.moeda_salario;

-- 9.2
SELECT c.cargo_nome, COUNT(*) AS funcionarios
FROM funcionarios f
JOIN cargos c ON c.cargo_id = f.cargo_id
GROUP BY c.cargo_id, c.cargo_nome
ORDER BY funcionarios DESC, c.cargo_nome
LIMIT 3;

-- 9.3: comparação na mesma moeda para que salários de moedas diferentes não se misturem.
SELECT f.funcionario_id, f.primeiro_nome, f.sobrenome,
       d.departamento_nome, f.salario, f.moeda_salario
FROM funcionarios f
JOIN departamentos d ON d.departamento_id = f.departamento_id
WHERE f.salario > (
  SELECT AVG(f2.salario)
  FROM funcionarios f2
  WHERE f2.departamento_id = f.departamento_id
    AND f2.moeda_salario = f.moeda_salario
)
ORDER BY d.departamento_nome, f.moeda_salario, f.salario DESC;

-- 9.4
SELECT YEAR(data_contratacao) AS ano, COUNT(*) AS contratacoes
FROM funcionarios
GROUP BY YEAR(data_contratacao)
ORDER BY ano;

-- 9.5: ranking de vendedores por transações e receita concluídas, por moeda.
SELECT f.funcionario_id, CONCAT(f.primeiro_nome, ' ', f.sobrenome) AS vendedor,
       i.moeda, COUNT(DISTINCT v.venda_id) AS vendas,
       SUM(i.quantidade * i.preco_unitario) AS receita
FROM funcionarios f
JOIN vendas v ON v.funcionario_id = f.funcionario_id
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
JOIN itens_venda i ON i.venda_id = v.venda_id
WHERE sv.nome = 'CONCLUIDA'
GROUP BY f.funcionario_id, f.primeiro_nome, f.sobrenome, i.moeda
ORDER BY receita DESC;

-- 9.6: produtos associados a somente um vendedor em vendas concluídas.
SELECT p.produto_id, p.sku, p.produto_nome,
       COUNT(DISTINCT v.funcionario_id) AS vendedores
FROM produtos p
JOIN itens_venda i ON i.produto_id = p.produto_id
JOIN vendas v ON v.venda_id = i.venda_id
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
WHERE sv.nome = 'CONCLUIDA'
GROUP BY p.produto_id, p.sku, p.produto_nome
HAVING COUNT(DISTINCT v.funcionario_id) = 1
ORDER BY p.produto_nome;

-- NÍVEL 10 — AUDITORIA DE VENDAS
-- 10.1: o esquema impede vendas sem vendedor (NOT NULL + chave estrangeira).
-- A consulta deve retornar zero linhas; staging permite localizar registros sem associação.
SELECT venda_id, referencia_origem, data_venda
FROM vendas
WHERE funcionario_id IS NULL;
SELECT source_row_id, pedido_ref, email_vendedor_raw
FROM stg_vendas_csv s
LEFT JOIN funcionarios f ON LOWER(f.email) = LOWER(TRIM(s.email_vendedor_raw))
WHERE NULLIF(TRIM(s.email_vendedor_raw), '') IS NULL
   OR f.funcionario_id IS NULL;

-- 10.2: também é impedido pela chave estrangeira; esta consulta serve como auditoria.
SELECT v.venda_id, v.referencia_origem, v.funcionario_id
FROM vendas v
LEFT JOIN funcionarios f ON f.funcionario_id = v.funcionario_id
WHERE f.funcionario_id IS NULL;

-- 10.3: amplitude maior que 10% do menor preço; compara moeda e vendas concluídas.
SELECT p.sku, p.produto_nome, i.moeda,
       MIN(i.preco_unitario) AS menor_preco,
       MAX(i.preco_unitario) AS maior_preco,
       ROUND(100 * (MAX(i.preco_unitario) - MIN(i.preco_unitario))
             / NULLIF(MIN(i.preco_unitario), 0), 2) AS variacao_percentual
FROM itens_venda i
JOIN produtos p ON p.produto_id = i.produto_id
JOIN vendas v ON v.venda_id = i.venda_id
JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
WHERE sv.nome = 'CONCLUIDA'
GROUP BY p.produto_id, p.sku, p.produto_nome, i.moeda
HAVING MIN(i.preco_unitario) > 0
   AND (MAX(i.preco_unitario) - MIN(i.preco_unitario)) / MIN(i.preco_unitario) > 0.10
ORDER BY variacao_percentual DESC;

-- 10.4: uma consulta retorna um único registro com as seis métricas do dashboard.
WITH folha_por_moeda AS (
  SELECT moeda_salario AS moeda, SUM(salario) AS total
  FROM funcionarios
  GROUP BY moeda_salario
),
receita_por_moeda AS (
  SELECT i.moeda, SUM(i.quantidade * i.preco_unitario) AS total
  FROM itens_venda i
  JOIN vendas v ON v.venda_id = i.venda_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY i.moeda
),
produto_mais_vendido AS (
  SELECT p.produto_nome, SUM(i.quantidade) AS unidades
  FROM produtos p
  JOIN itens_venda i ON i.produto_id = p.produto_id
  JOIN vendas v ON v.venda_id = i.venda_id
  JOIN status_venda sv ON sv.status_venda_id = v.status_venda_id
  WHERE sv.nome = 'CONCLUIDA'
  GROUP BY p.produto_id, p.produto_nome
  ORDER BY unidades DESC, p.produto_nome
  LIMIT 1
)
SELECT
  (SELECT COUNT(*) FROM funcionarios) AS total_funcionarios,
  (SELECT JSON_OBJECTAGG(moeda, total) FROM folha_por_moeda)
    AS custo_total_salarios_por_moeda,
  (SELECT COUNT(*) FROM departamentos) AS total_departamentos,
  (SELECT COUNT(*) FROM escritorios) AS total_escritorios,
  (SELECT JSON_OBJECTAGG(moeda, total) FROM receita_por_moeda)
    AS receita_total_vendas_por_moeda,
  (SELECT produto_nome FROM produto_mais_vendido) AS produto_mais_vendido;
-- O modelo contém várias moedas; os totais do dashboard são objetos por moeda,
-- pois não existe taxa de câmbio para produzir um único valor comparável.
