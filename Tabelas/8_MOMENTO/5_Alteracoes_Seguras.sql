-- Nível 12 (e atualização segura do antigo 6): alterações em uma transação.
-- Revise os SELECTs de conferência. O arquivo termina em ROLLBACK por segurança;
-- troque por COMMIT somente depois de validar os resultados no seu ambiente.
USE momento;
START TRANSACTION;

SET @escritorio_wayne = (
  SELECT escritorio_id FROM escritorios
  WHERE escritorio_nome = 'Wayne Offices'
  LIMIT 1
);
SET @departamento_tecnologia = (
  SELECT departamento_id FROM departamentos
  WHERE departamento_nome = 'Tecnologia da Informação'
  ORDER BY departamento_id
  LIMIT 1
);
SET @departamento_inovacoes = COALESCE(
  (SELECT departamento_id FROM departamentos
   WHERE departamento_nome = 'Inovações'
     AND escritorio_id = @escritorio_wayne
   LIMIT 1),
  (SELECT COALESCE(MAX(departamento_id), 0) + 1 FROM departamentos)
);

-- 12.1 Cria o departamento se ainda não existir no Wayne Offices.
INSERT INTO departamentos (departamento_id, departamento_nome, educacional, escritorio_id)
SELECT @departamento_inovacoes, 'Inovações', FALSE, @escritorio_wayne
WHERE @escritorio_wayne IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM departamentos
    WHERE departamento_nome = 'Inovações'
      AND escritorio_id = @escritorio_wayne
  );

-- 12.3 Escolha reprodutível: duas pessoas ativas mais recentemente contratadas
-- na Tecnologia, exceto Bruce, cuja promoção está especificada separadamente.
-- Esse critério é apenas uma regra didática; confirme a decisão com a equipe.
DROP TEMPORARY TABLE IF EXISTS momento_transferencias;
CREATE TEMPORARY TABLE momento_transferencias AS
SELECT f.funcionario_id, f.primeiro_nome, f.sobrenome, f.data_contratacao
FROM funcionarios f
JOIN status_funcionario sf ON sf.status_funcionario_id = f.status_funcionario_id
WHERE f.departamento_id = @departamento_tecnologia
  AND sf.nome = 'ATIVO'
  AND f.email <> 'bruce.ernst@momento.org'
ORDER BY f.data_contratacao DESC, f.funcionario_id DESC
LIMIT 2;

SELECT * FROM momento_transferencias ORDER BY data_contratacao DESC, funcionario_id DESC;

UPDATE funcionarios f
JOIN momento_transferencias t ON t.funcionario_id = f.funcionario_id
SET f.departamento_id = @departamento_inovacoes;

-- 12.4 Reajusta em 10% quem permaneceu na Tecnologia.
UPDATE funcionarios
SET salario = ROUND(salario * 1.10, 2)
WHERE departamento_id = @departamento_tecnologia;

-- Registra o cargo se ainda não existir. Faixa reaproveita a faixa atual de
-- Desenvolvedor Web; ajuste-a se a política salarial local definir outra.
SET @cargo_senior_web = COALESCE(
  (SELECT cargo_id FROM cargos WHERE cargo_nome = 'Senior Web Developer' LIMIT 1),
  (SELECT COALESCE(MAX(cargo_id), 0) + 1 FROM cargos)
);
INSERT INTO cargos (cargo_id, cargo_nome, min_salario, max_salario)
SELECT @cargo_senior_web, 'Senior Web Developer', 4000.00, 10000.00
WHERE NOT EXISTS (
  SELECT 1 FROM cargos WHERE cargo_nome = 'Senior Web Developer'
);

-- 12.2 A instrução pede salário final de 5.000. No seed atual Bruce recebe 6.000,
-- portanto 5.000 é uma redução nominal, apesar do texto chamar de aumento.
UPDATE funcionarios
SET cargo_id = @cargo_senior_web,
    salario = 5000.00
WHERE LOWER(email) = 'bruce.ernst@momento.org';

-- 12.5 Compra de headsets com moeda, data e referência rastreável.
INSERT INTO suprimentos
  (suprimento_id, referencia_compra, suprimento_nome, quantidade_estoque,
   custo_unitario, moeda, data_compra, escritorio_id)
SELECT (SELECT COALESCE(MAX(suprimento_id), 0) + 1 FROM suprimentos),
       'PO-HEADSET-MOMENTO-2026-01', 'Headsets', 15, 150.00, 'USD',
       CURRENT_DATE, @escritorio_wayne
WHERE @escritorio_wayne IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM suprimentos
    WHERE referencia_compra = 'PO-HEADSET-MOMENTO-2026-01'
  );

-- 12.6 Simula aposentadoria sem apagar histórico ou quebrar referências.
UPDATE funcionarios f
JOIN status_funcionario sf ON sf.nome = 'INATIVO'
SET f.status_funcionario_id = sf.status_funcionario_id
WHERE f.data_contratacao < '1990-01-01';

-- Conferências dentro da transação, antes de decidir COMMIT.
SELECT d.departamento_nome, e.escritorio_nome, d.departamento_id
FROM departamentos d
JOIN escritorios e ON e.escritorio_id = d.escritorio_id
WHERE d.departamento_id = @departamento_inovacoes;

SELECT f.funcionario_id, f.primeiro_nome, f.sobrenome, d.departamento_nome,
       f.data_contratacao, f.salario, f.moeda_salario
FROM funcionarios f
JOIN departamentos d ON d.departamento_id = f.departamento_id
WHERE d.departamento_id IN (@departamento_tecnologia, @departamento_inovacoes)
ORDER BY d.departamento_nome, f.data_contratacao DESC;

SELECT f.funcionario_id, f.primeiro_nome, f.sobrenome, c.cargo_nome,
       f.salario, f.moeda_salario
FROM funcionarios f
JOIN cargos c ON c.cargo_id = f.cargo_id
WHERE LOWER(f.email) = 'bruce.ernst@momento.org';

SELECT s.referencia_compra, s.suprimento_nome, s.quantidade_estoque,
       s.custo_unitario, s.moeda, s.data_compra, e.escritorio_nome
FROM suprimentos s
JOIN escritorios e ON e.escritorio_id = s.escritorio_id
WHERE s.referencia_compra = 'PO-HEADSET-MOMENTO-2026-01';

SELECT sf.nome AS status, COUNT(*) AS funcionarios_anteriores_a_1990
FROM funcionarios f
JOIN status_funcionario sf ON sf.status_funcionario_id = f.status_funcionario_id
WHERE f.data_contratacao < '1990-01-01'
GROUP BY sf.nome;

-- Padrão seguro: rever os resultados acima e então trocar a linha seguinte por COMMIT.
ROLLBACK;
