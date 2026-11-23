// Gabarito MongoDB dos exercícios de Documentos/6_MOMENTO/README.md.
// Execute após importar o modelo atual: mongosh --file importar.js
// As consultas usam os IDs numéricos e referências descritos em MODELO.md.
// Vendas são exportadas no grão de item e conservam preço/moeda históricos.
// Valores financeiros ficam separados por moeda quando a comparação exige soma.
const momento = db.getSiblingDB("momento");
const mostrar = (titulo, cursor) => {
  print("\n--- " + titulo + " ---");
  if (cursor && typeof cursor.forEach === "function") cursor.forEach(doc => printjson(doc));
  else printjson(cursor);
};

// 1.1 — cadastre-se com seus próprios dados; consulte cargos e departamentos antes.
mostrar("Cargos disponíveis", momento.cargos.find({}, {nome: 1, salario_minimo: 1, salario_maximo: 1}).sort({nome: 1}));
mostrar("Departamentos", momento.departamentos.find({}, {nome: 1, escritorio_id: 1}).sort({nome: 1}));
// Modelo de insert (preencha todos os campos, inclusive os obrigatórios do validator):
// momento.funcionarios.insertOne({
//   _id: <ID_NUMERICO_NAO_USADO>,
//   primeiro_nome: "<SEU_NOME>", sobrenome: "<SEU_SOBRENOME>",
//   email: "<SEU_EMAIL_UNICO>",
//   telefone: null, data_contratacao: new Date(),
//   cargo_id: <ID_DE_CARGO>, salario: NumberDecimal("5000.00"),
//   moeda_salario: "USD", gerente_id: null,
//   departamento_id: <ID_DE_TECNOLOGIA>, status_funcionario_id: 1,
//   dependentes: []
// });

// 1.2
mostrar("Total de funcionários", momento.funcionarios.aggregate([
  {$count: "total_funcionarios"}
]));

// 1.3 — resolve o nome do departamento pela referência.
mostrar("Funcionários em Tecnologia", momento.departamentos.aggregate([
  {$match: {nome: /Tecnologia/i}},
  {$lookup: {from: "funcionarios", localField: "_id", foreignField: "departamento_id", as: "equipe"}},
  {$project: {_id: 0, departamento: "$nome", total_funcionarios: {$size: "$equipe"}}}
]));

// 1.4
mostrar("Departamentos existentes", momento.departamentos.find({}, {nome: 1, escritorio_id: 1}).sort({nome: 1}));
mostrar("Quantidade de departamentos", momento.departamentos.aggregate([{$count: "total_departamentos"}]));

// 1.5
mostrar("Escritórios e países", momento.escritorios.aggregate([
  {$lookup: {from: "paises", localField: "pais_id", foreignField: "_id", as: "pais"}},
  {$unwind: "$pais"},
  {$group: {_id: "$pais._id", pais: {$first: "$pais.nome"}, escritorios: {$sum: 1}}},
  {$sort: {pais: 1}}
]));
mostrar("Total de escritórios e países", momento.escritorios.aggregate([
  {$group: {_id: null, escritorios: {$sum: 1}, paises: {$addToSet: "$pais_id"}}},
  {$project: {_id: 0, total_escritorios: "$escritorios", total_paises: {$size: "$paises"}}}
]));

// 2.1–2.2
mostrar("Funcionários e folha de Vendas", momento.funcionarios.aggregate([
  {$lookup: {from: "departamentos", localField: "departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$match: {$expr: {$eq: [{$toLower: "$departamento.nome"}, "vendas"]}}},
  {$group: {
    _id: {$ifNull: ["$moeda_salario", "USD"]},
    funcionarios: {$sum: 1},
    custo_total_salarios: {$sum: "$salario"}
  }},
  {$project: {_id: 0, moeda: "$_id", funcionarios: 1, custo_total_salarios: 1}}
]));

// 2.3
mostrar("Média salarial sem CEO, CMO e CFO", momento.funcionarios.aggregate([
  {$lookup: {from: "cargos", localField: "cargo_id", foreignField: "_id", as: "cargo"}},
  {$unwind: "$cargo"},
  {$match: {"cargo.nome": {$nin: ["CEO", "CMO", "CFO"]}}},
  {$group: {_id: {$ifNull: ["$moeda_salario", "USD"]}, media: {$avg: "$salario"}}},
  {$project: {_id: 0, moeda: "$_id", salario_medio: {$round: ["$media", 2]}}}
]));

// 2.4
mostrar("Média salarial de Tecnologia", momento.funcionarios.aggregate([
  {$lookup: {from: "departamentos", localField: "departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$match: {"departamento.nome": /Tecnologia/i}},
  {$group: {_id: {$ifNull: ["$moeda_salario", "USD"]}, media: {$avg: "$salario"}}},
  {$project: {_id: 0, moeda: "$_id", salario_medio: {$round: ["$media", 2]}}}
]));

// 2.5 — maior média por moeda, mantendo empates.
mostrar("Departamento com maior média salarial", momento.funcionarios.aggregate([
  {$group: {_id: {
    departamento_id: "$departamento_id",
    moeda: {$ifNull: ["$moeda_salario", "USD"]}
  }, media: {$avg: "$salario"}}},
  {$sort: {"_id.moeda": 1, media: -1}},
  {$group: {_id: "$_id.moeda", maximo: {$first: "$media"}, grupos: {$push: "$$ROOT"}}},
  {$unwind: "$grupos"},
  {$match: {$expr: {$eq: ["$grupos.media", "$maximo"]}}},
  {$lookup: {from: "departamentos", localField: "grupos._id.departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$project: {_id: 0, moeda: "$_id", departamento: "$departamento.nome", media_salarial: "$grupos.media"}}
]));

// 2.6 — inclui departamento sem funcionários.
mostrar("Departamento com menor equipe", momento.departamentos.aggregate([
  {$lookup: {from: "funcionarios", localField: "_id", foreignField: "departamento_id", as: "equipe"}},
  {$project: {nome: 1, total_funcionarios: {$size: "$equipe"}}},
  {$sort: {total_funcionarios: 1, nome: 1}},
  {$limit: 1}
]));

// 3.1–3.2 — dependentes estão incorporados em cada funcionário.
mostrar("Funcionários com cônjuge", momento.funcionarios.aggregate([
  {$match: {dependentes: {$elemMatch: {relacionamento: "Cônjuge"}}}},
  {$count: "funcionarios_com_conjuge"}
]));
mostrar("Funcionários com filhos", momento.funcionarios.aggregate([
  {$match: {dependentes: {$elemMatch: {relacionamento: /filho/i}}}},
  {$count: "funcionarios_com_filhos"}
]));

// 3.3–3.5
mostrar("Mais antigo na empresa", momento.funcionarios.find(
  {}, {primeiro_nome: 1, sobrenome: 1, data_contratacao: 1}
).sort({data_contratacao: 1, _id: 1}).limit(1));
mostrar("Contratação mais recente", momento.funcionarios.find(
  {}, {primeiro_nome: 1, sobrenome: 1, data_contratacao: 1}
).sort({data_contratacao: -1, _id: -1}).limit(1));
mostrar("Cinco funcionários mais antigos", momento.funcionarios.find(
  {}, {primeiro_nome: 1, sobrenome: 1, data_contratacao: 1}
).sort({data_contratacao: 1, _id: 1}).limit(5));

// 3.6
mostrar("Contratados na década de 1990", momento.funcionarios.aggregate([
  {$match: {data_contratacao: {$gte: ISODate("1990-01-01"), $lt: ISODate("2000-01-01")}}},
  {$count: "total"}
]));

// 3.7 — moeda permanece explícita quando presente no documento.
mostrar("Média salarial por ano de contratação", momento.funcionarios.aggregate([
  {$group: {
    _id: {ano: {$year: "$data_contratacao"}, moeda: {$ifNull: ["$moeda_salario", "USD"]}},
    contratacoes: {$sum: 1}, media: {$avg: "$salario"}
  }},
  {$project: {_id: 0, ano: "$_id.ano", moeda: "$_id.moeda",
    contratacoes: 1, salario_medio: {$round: ["$media", 2]}}},
  {$sort: {ano: 1, moeda: 1}}
]));

// 4.1 — custo de estoque = quantidade × custo unitário, por moeda.
mostrar("Soma dos custos registrados por escritório", momento.escritorios.aggregate([
  {$unwind: "$suprimentos"},
  {$group: {_id: {escritorio_id: "$_id", moeda: "$suprimentos.moeda"},
    escritorio: {$first: "$nome"},
    custo_total: {$sum: {$multiply: ["$suprimentos.quantidade", "$suprimentos.custo_unitario"]}}}},
  {$sort: {custo_total: -1}}
]));

// 4.2
mostrar("Escritório com mais tipos de suprimento", momento.escritorios.aggregate([
  {$project: {nome: 1, tipos: {$setUnion: [[], {$map: {
    input: {$ifNull: ["$suprimentos", []]}, as: "s", in: "$$s.nome"
  }}]}}},
  {$project: {nome: 1, tipos_suprimento: {$size: "$tipos"}}},
  {$sort: {tipos_suprimento: -1, nome: 1}},
  {$limit: 1}
]));

// 4.3 — maior custo unitário por moeda.
mostrar("Maior custo registrado em um suprimento", momento.escritorios.aggregate([
  {$unwind: "$suprimentos"},
  {$sort: {"suprimentos.moeda": 1, "suprimentos.custo_unitario": -1}},
  {$group: {_id: "$suprimentos.moeda", escritorio: {$first: "$nome"},
    suprimento: {$first: "$suprimentos.nome"},
    custo_unitario: {$first: "$suprimentos.custo_unitario"}}},
  {$sort: {_id: 1}}
]));
// 4.4
mostrar("Valor do inventário de suprimentos por moeda", momento.escritorios.aggregate([
  {$unwind: "$suprimentos"},
  {$group: {_id: "$suprimentos.moeda",
    valor_inventario: {$sum: {$multiply: ["$suprimentos.quantidade", "$suprimentos.custo_unitario"]}}}}
]));

// 5.1 — produtos que aparecem em vendas concluídas.
mostrar("Produtos vendidos", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: "$produto_id"}},
  {$lookup: {from: "produtos", localField: "_id", foreignField: "_id", as: "produto"}},
  {$unwind: "$produto"},
  {$project: {_id: "$produto._id", nome: "$produto.nome"}},
  {$sort: {nome: 1}}
]));

// 5.2–5.3: quantidade de unidades por produto, incluindo o catálogo sem vendas.
mostrar("Produto(s) mais vendido(s)", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: "$produto_id", unidades: {$sum: "$quantidade"}}},
  {$sort: {unidades: -1, _id: 1}},
  {$limit: 1},
  {$lookup: {from: "produtos", localField: "_id", foreignField: "_id", as: "produto"}},
  {$unwind: "$produto"},
  {$project: {produto: "$produto.nome", unidades: 1}}
]));
mostrar("Produto(s) menos vendido(s), entre os vendidos", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: "$produto_id", unidades: {$sum: "$quantidade"}}},
  {$sort: {unidades: 1, _id: 1}},
  {$limit: 1},
  {$lookup: {from: "produtos", localField: "_id", foreignField: "_id", as: "produto"}},
  {$unwind: "$produto"},
  {$project: {produto: "$produto.nome", unidades: 1}}
]));

// 5.4 — usa o preço histórico de cada item, separado por moeda.
mostrar("Produto com maior receita em cada moeda", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: {produto_id: "$produto_id", moeda: "$moeda"},
    receita: {$sum: {$multiply: ["$quantidade", "$preco_unitario"]}}}},
  {$sort: {"_id.moeda": 1, receita: -1}},
  {$group: {_id: "$_id.moeda", produto_id: {$first: "$_id.produto_id"}, receita: {$first: "$receita"}}},
  {$lookup: {from: "produtos", localField: "produto_id", foreignField: "_id", as: "produto"}},
  {$unwind: "$produto"},
  {$project: {_id: 0, moeda: "$_id", produto: "$produto.nome", receita: 1}}
]));

// 5.6
mostrar("Faturamento histórico total por moeda", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: "$moeda",
    faturamento: {$sum: {$multiply: ["$quantidade", "$preco_unitario"]}}}},
  {$sort: {_id: 1}}
]));

// 5.5 — catálogo não expõe moeda; os dados de origem usam o valor atual documentado.
mostrar("Produto mais caro do catálogo", momento.produtos.find(
  {}, {nome: 1, preco_unitario: 1}
).sort({preco_unitario: -1, _id: 1}).limit(1));

// 5.7
mostrar("Vendas em junho de 2023", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA",
    data_venda: {$gte: ISODate("2023-06-01"), $lt: ISODate("2023-07-01")}}},
  {$group: {_id: "$venda_id"}},
  {$count: "total_vendas"}
]));

// 5.8 — conta tickets distintos, pois cada documento Mongo é uma linha de item.
mostrar("Vendedor com mais transações", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: {funcionario_id: "$funcionario_id", venda_id: "$venda_id"}}},
  {$group: {_id: "$_id.funcionario_id", vendas: {$sum: 1}}},
  {$sort: {vendas: -1, _id: 1}},
  {$limit: 1},
  {$lookup: {from: "funcionarios", localField: "_id", foreignField: "_id", as: "funcionario"}},
  {$unwind: "$funcionario"},
  {$project: {vendas: 1, vendedor: {$concat: ["$funcionario.primeiro_nome", " ", "$funcionario.sobrenome"]}}}
]));

// 5.9 — receita e quantidade de tickets por vendedor/moeda.
mostrar("Receita histórica por vendedor", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: {funcionario_id: "$funcionario_id", moeda: "$moeda"},
    tickets: {$addToSet: "$venda_id"},
    receita: {$sum: {$multiply: ["$quantidade", "$preco_unitario"]}}}},
  {$lookup: {from: "funcionarios", localField: "_id.funcionario_id", foreignField: "_id", as: "funcionario"}},
  {$unwind: "$funcionario"},
  {$project: {moeda: "$_id.moeda", vendas: {$size: "$tickets"}, receita: 1,
    vendedor: {$concat: ["$funcionario.primeiro_nome", " ", "$funcionario.sobrenome"]}}},
  {$sort: {receita: -1}}
]));

// NÍVEL 6 — atualizações: veja alteracoes_seguras.js. Em especial, não apague
// funcionários referenciados; prefira alterar status_funcionario_id para INATIVO.

// 7.1 — folha, quantidade e média de cada departamento.
mostrar("Relatório por departamento", momento.funcionarios.aggregate([
  {$group: {_id: {
    departamento_id: "$departamento_id",
    moeda: {$ifNull: ["$moeda_salario", "USD"]}
  }, funcionarios: {$sum: 1}, folha: {$sum: "$salario"}, media: {$avg: "$salario"}}},
  {$lookup: {from: "departamentos", localField: "_id.departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$project: {_id: 0, departamento: "$departamento.nome", moeda: "$_id.moeda",
    funcionarios: 1, folha: 1, media: {$round: ["$media", 2]}}},
  {$sort: {departamento: 1, moeda: 1}}
]));

// 7.2
mostrar("Três cargos mais comuns", momento.funcionarios.aggregate([
  {$group: {_id: "$cargo_id", funcionarios: {$sum: 1}}},
  {$sort: {funcionarios: -1, _id: 1}},
  {$limit: 3},
  {$lookup: {from: "cargos", localField: "_id", foreignField: "_id", as: "cargo"}},
  {$unwind: "$cargo"},
  {$project: {_id: 0, cargo: "$cargo.nome", funcionarios: 1}}
]));

// 7.3 — média no departamento e na mesma moeda.
mostrar("Acima da média salarial do departamento", momento.funcionarios.aggregate([
  {$lookup: {
    from: "funcionarios",
    let: {dep: "$departamento_id", moeda: {$ifNull: ["$moeda_salario", "USD"]}},
    pipeline: [
      {$match: {$expr: {$and: [
        {$eq: ["$departamento_id", "$$dep"]},
        {$eq: [{$ifNull: ["$moeda_salario", "USD"]}, "$$moeda"]}
      ]}}},
      {$group: {_id: null, media: {$avg: "$salario"}}}
    ],
    as: "media_departamento"
  }},
  {$unwind: "$media_departamento"},
  {$match: {$expr: {$gt: ["$salario", "$media_departamento.media"]}}},
  {$lookup: {from: "departamentos", localField: "departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$project: {primeiro_nome: 1, sobrenome: 1, departamento: "$departamento.nome",
    salario: 1, media_departamento: "$media_departamento.media"}}
]));

// 7.4
mostrar("Contratações por ano", momento.funcionarios.aggregate([
  {$group: {_id: {$year: "$data_contratacao"}, contratacoes: {$sum: 1}}},
  {$sort: {_id: 1}}
]));

// 7.5
mostrar("Ranking dos vendedores", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: {funcionario_id: "$funcionario_id", moeda: "$moeda"},
    tickets: {$addToSet: "$venda_id"},
    receita: {$sum: {$multiply: ["$quantidade", "$preco_unitario"]}}}},
  {$lookup: {from: "funcionarios", localField: "_id.funcionario_id", foreignField: "_id", as: "funcionario"}},
  {$unwind: "$funcionario"},
  {$project: {moeda: "$_id.moeda", vendas: {$size: "$tickets"}, receita: 1,
    vendedor: {$concat: ["$funcionario.primeiro_nome", " ", "$funcionario.sobrenome"]}}},
  {$sort: {receita: -1}}
]));

// 7.6
mostrar("Produtos vendidos por um único vendedor", momento.vendas.aggregate([
  {$group: {_id: "$produto_id", vendedores: {$addToSet: "$funcionario_id"}}},
  {$match: {$expr: {$eq: [{$size: "$vendedores"}, 1]}}},
  {$lookup: {from: "produtos", localField: "_id", foreignField: "_id", as: "produto"}},
  {$unwind: "$produto"},
  {$project: {produto: "$produto.nome", vendedor_id: {$arrayElemAt: ["$vendedores", 0]}}}
]));

// 8.1 — três formas de consultar cônjuge OU filhos em Vendas.
const equipeVendas = momento.departamentos.findOne({nome: "Vendas"});
if (equipeVendas) {
  mostrar("Dependentes em Vendas: $or", momento.funcionarios.find({
    departamento_id: equipeVendas._id,
    $or: [
      {"dependentes.relacionamento": "Cônjuge"},
      {"dependentes.relacionamento": /filho/i}
    ]
  }));
  mostrar("Dependentes em Vendas: $elemMatch", momento.funcionarios.find({
    departamento_id: equipeVendas._id,
    dependentes: {$elemMatch: {relacionamento: {$in: ["Cônjuge", "Filha(o)"]}}}
  }));
  mostrar("Dependentes em Vendas: agregação com $filter", momento.funcionarios.aggregate([
    {$match: {departamento_id: equipeVendas._id}},
    {$set: {dependentes_relevantes: {$filter: {
      input: "$dependentes", as: "d",
      cond: {$or: [
        {$eq: ["$$d.relacionamento", "Cônjuge"]},
        {$regexMatch: {input: "$$d.relacionamento", regex: /filho/i}}
      ]}
    }}}},
    {$match: {$expr: {$gt: [{$size: "$dependentes_relevantes"}, 0]}}}
  ]));
}
// Para comparar desempenho real, use .explain("executionStats") com os mesmos filtros.
// O índice em funcionarios.departamento_id favorece a seleção do departamento;
// o array dependentes é filtrado depois, salvo criação de índice multikey específico.

// 8.2 — no modelo atual, funcionário só tem departamento_id. A localização é herdada
// do departamento; não há um segundo escritorio_id no funcionário para comparar.
mostrar("Funcionários com escritório próprio explicitamente informado", momento.funcionarios.find({
  escritorio_id: {$exists: true}
}));

// 8.3 — um documento por escritório; salários são discriminados por moeda.
mostrar("Resumo dos escritórios", momento.escritorios.aggregate([
  {$lookup: {from: "paises", localField: "pais_id", foreignField: "_id", as: "pais"}},
  {$unwind: "$pais"},
  {$lookup: {from: "departamentos", localField: "_id", foreignField: "escritorio_id", as: "departamentos"}},
  {$lookup: {
    from: "funcionarios",
    let: {ids: "$departamentos._id"},
    pipeline: [
      {$match: {$expr: {$in: ["$departamento_id", "$$ids"]}}},
      {$group: {_id: {$ifNull: ["$moeda_salario", "USD"]},
        funcionarios: {$sum: 1}, salarios: {$sum: "$salario"}}}
    ],
    as: "folha_por_moeda"
  }},
  {$lookup: {
    from: "escritorios",
    let: {id: "$_id"},
    pipeline: [
      {$match: {$expr: {$eq: ["$_id", "$$id"]}}},
      {$unwind: "$suprimentos"},
      {$group: {_id: "$suprimentos.moeda",
        custo_total: {$sum: {$multiply: ["$suprimentos.quantidade", "$suprimentos.custo_unitario"]}}}}
    ],
    as: "suprimentos_por_moeda"
  }},
  {$project: {
    escritorio: "$nome", pais: "$pais.nome",
    departamentos: {$size: "$departamentos"},
    funcionarios: {$reduce: {input: "$folha_por_moeda", initialValue: 0,
      in: {$add: ["$$value", "$$this.funcionarios"]}}},
    folha_por_moeda: 1,
    suprimentos_por_moeda: 1
  }},
  {$sort: {pais: 1, escritorio: 1}}
]));

// 8.4a — cargos ocupados em departamentos das duas frentes.
mostrar("Cargos compartilhados entre as frentes", momento.funcionarios.aggregate([
  {$lookup: {from: "departamentos", localField: "departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$lookup: {from: "cargos", localField: "cargo_id", foreignField: "_id", as: "cargo"}},
  {$unwind: "$cargo"},
  {$group: {_id: "$cargo.nome",
    comercial: {$sum: {$cond: [{$eq: ["$departamento.educacional", false]}, 1, 0]}},
    educacional: {$sum: {$cond: [{$eq: ["$departamento.educacional", true]}, 1, 0]}}}},
  {$match: {comercial: {$gt: 0}, educacional: {$gt: 0}}},
  {$project: {_id: 0, cargo: "$_id", comercial: 1, educacional: 1}}
]));
// 8.4b — mesmo nome de departamento cadastrado em ambas as frentes.
mostrar("Departamentos com nomes compartilhados entre as frentes", momento.departamentos.aggregate([
  {$group: {_id: "$nome", frentes: {$addToSet: "$educacional"}}},
  {$match: {$expr: {$eq: [{$size: "$frentes"}, 2]}}},
  {$project: {_id: 0, departamento: "$_id"}}
]));

// 8.5 — busca textual simples por nome de produto.
mostrar("Produtos com Uniforme no nome", momento.produtos.find({nome: /Uniforme/i}));

// 8.6
mostrar("Vendas no segundo trimestre de 2023", momento.vendas.find({
  data_venda: {$gte: ISODate("2023-04-01"), $lt: ISODate("2023-07-01")}
}).sort({data_venda: 1}));

// 9.1 — três formas equivalentes; restringe a USD para não misturar moedas.
mostrar("Salários de 6.000 a 10.000: $gte/$lte", momento.funcionarios.find({
  moeda_salario: "USD",
  salario: {$gte: NumberDecimal("6000.00"), $lte: NumberDecimal("10000.00")}
}));
mostrar("Salários de 6.000 a 10.000: $and", momento.funcionarios.find({
  $and: [
    {moeda_salario: "USD"},
    {salario: {$gte: NumberDecimal("6000.00")}},
    {salario: {$lte: NumberDecimal("10000.00")}}
  ]
}));
mostrar("Salários de 6.000 a 10.000: $expr", momento.funcionarios.find({
  moeda_salario: "USD",
  $expr: {$and: [
    {$gte: ["$salario", NumberDecimal("6000.00")]},
    {$lte: ["$salario", NumberDecimal("10000.00")]}
  ]}
}));

// 9.2 — a opção A é preferível: ambos os predicados no servidor permitem usar índices.
// A opção B transfere documentos para filtrar no cliente. Neste modelo, compare por
// departamento_id numérico (não cargo/ObjectId) e execute explain para medir.
mostrar("Vendas com salário acima de 7.000", momento.funcionarios.find({
  departamento_id: equipeVendas ? equipeVendas._id : -1,
  moeda_salario: "USD",
  salario: {$gt: NumberDecimal("7000.00")}
}));

// 9.3 — email é obrigatório no schema; telefone é anulável. A consulta também cobre
// documentos antigos que possam ter campos ausentes.
mostrar("Sem email ou telefone", momento.funcionarios.find({
  $or: [
    {email: {$exists: false}},
    {email: null},
    {telefone: {$exists: false}},
    {telefone: null},
    {telefone: ""}
  ]
}));

// 9.4 — funcionário único em seu cargo dentro do departamento.
mostrar("Funcionários únicos no cargo/departamento", momento.funcionarios.aggregate([
  {$lookup: {
    from: "funcionarios",
    let: {dep: "$departamento_id", cargo: "$cargo_id"},
    pipeline: [
      {$match: {$expr: {$and: [
        {$eq: ["$departamento_id", "$$dep"]}, {$eq: ["$cargo_id", "$$cargo"]}
      ]}}},
      {$count: "quantidade"}
    ],
    as: "colegas_mesmo_cargo"
  }},
  {$match: {$expr: {$eq: [{$ifNull: [{$arrayElemAt: ["$colegas_mesmo_cargo.quantidade", 0]}, 0]}, 1]}}},
  {$lookup: {from: "departamentos", localField: "departamento_id", foreignField: "_id", as: "departamento"}},
  {$unwind: "$departamento"},
  {$lookup: {from: "cargos", localField: "cargo_id", foreignField: "_id", as: "cargo"}},
  {$unwind: "$cargo"},
  {$project: {primeiro_nome: 1, sobrenome: 1, departamento: "$departamento.nome", cargo: "$cargo.nome"}}
]));

// 9.5 — o enunciado chama de receita a soma de salários e suprimentos; isso é
// custo observado. Os valores são apresentados por moeda, sem conversão cambial.
mostrar("Países: escritórios, departamentos, equipe e receita estimada", momento.paises.aggregate([
  {$lookup: {from: "escritorios", localField: "_id", foreignField: "pais_id", as: "escritorios"}},
  {$addFields: {escritorio_ids: {$map: {input: "$escritorios", as: "e", in: "$$e._id"}}}},
  {$lookup: {
    from: "departamentos", let: {ids: "$escritorio_ids"},
    pipeline: [{$match: {$expr: {$in: ["$escritorio_id", "$$ids"]}}}],
    as: "departamentos"
  }},
  {$addFields: {departamento_ids: {$map: {input: "$departamentos", as: "d", in: "$$d._id"}}}},
  {$lookup: {
    from: "funcionarios", let: {ids: "$departamento_ids"},
    pipeline: [
      {$match: {$expr: {$in: ["$departamento_id", "$$ids"]}}},
      {$group: {_id: {$ifNull: ["$moeda_salario", "USD"]},
        funcionarios: {$sum: 1}, salarios: {$sum: "$salario"}}}
    ],
    as: "equipe"
  }},
  {$addFields: {total_funcionarios: {$sum: "$equipe.funcionarios"}}},
  {$lookup: {
    from: "escritorios", let: {country: "$_id"},
    pipeline: [
      {$match: {$expr: {$eq: ["$pais_id", "$$country"]}}},
      {$unwind: "$suprimentos"},
      {$group: {_id: "$suprimentos.moeda",
        total: {$sum: {$multiply: ["$suprimentos.quantidade", "$suprimentos.custo_unitario"]}}}}
    ],
    as: "custo_suprimentos"
  }},
  {$addFields: {moedas_relatorio: {$setUnion: [
    {$map: {input: "$equipe", as: "f", in: "$$f._id"}},
    {$map: {input: "$custo_suprimentos", as: "s", in: "$$s._id"}}
  ]}}},
  {$project: {_id: 0, pais: "$nome", escritorios: {$size: "$escritorios"},
    departamentos: {$size: "$departamentos"},
    funcionarios: "$total_funcionarios",
    custo_total_por_moeda: {$map: {input: "$moedas_relatorio", as: "moeda",
      in: {$let: {
        vars: {
          salarios: {$reduce: {input: "$equipe", initialValue: NumberDecimal("0.00"),
            in: {$cond: [{$eq: ["$$this._id", "$$moeda"]},
              {$add: ["$$value", "$$this.salarios"]}, "$$value"]}}},
          suprimentos: {$reduce: {input: "$custo_suprimentos", initialValue: NumberDecimal("0.00"),
            in: {$cond: [{$eq: ["$$this._id", "$$moeda"]},
              {$add: ["$$value", "$$this.total"]}, "$$value"]}}}
        },
        in: {moeda: "$$moeda", salarios: "$$salarios", suprimentos: "$$suprimentos",
          custo_total: {$add: ["$$salarios", "$$suprimentos"]}}
      }}
    }}
  }},
  {$sort: {pais: 1}}
]));

// 10.1–10.3 — operações de cadastro devem ser feitas após preencher referências reais.
// 10.1 Novo escritório: use pais_id de um país já cadastrado e um _id não usado.
// 10.2 Novo departamento: associe o escritorio_id escolhido no passo anterior.
// 10.3 Cadastre pessoas com emails únicos, cargo_id/departamento_id válidos e dados reais.
// 10.4 Três escritórios mais caros em cada moeda, sem comparar moedas distintas.
mostrar("Três escritórios com maior custo de suprimentos por moeda", momento.escritorios.aggregate([
  {$unwind: "$suprimentos"},
  {$group: {_id: {moeda: "$suprimentos.moeda", escritorio_id: "$_id"},
    escritorio: {$first: "$nome"},
    custo_total: {$sum: {$multiply: ["$suprimentos.quantidade", "$suprimentos.custo_unitario"]}}}},
  {$sort: {"_id.moeda": 1, custo_total: -1}},
  {$group: {_id: "$_id.moeda",
    escritorios: {$push: {nome: "$escritorio", custo_total: "$custo_total"}}}},
  {$project: {top_3: {$slice: ["$escritorios", 3]}}}
]));
// 10.5 Estoque acima de 50 unidades:
mostrar("Suprimentos com quantidade acima de 50", momento.escritorios.aggregate([
  {$unwind: "$suprimentos"},
  {$match: {"suprimentos.quantidade": {$gt: 50}}},
  {$project: {escritorio: "$nome", suprimento: "$suprimentos.nome",
    quantidade: "$suprimentos.quantidade", custo_unitario: "$suprimentos.custo_unitario",
    moeda: "$suprimentos.moeda"}}
]));
// 10.6 Economia potencial de 20%, calculada por moeda sem aplicar UPDATE.
mostrar("Economia potencial em salários acima de 15.000", momento.funcionarios.aggregate([
  {$match: {salario: {$gt: NumberDecimal("15000.00")}}},
  {$group: {_id: {$ifNull: ["$moeda_salario", "USD"]},
    salarios_alvo: {$sum: "$salario"}}},
  {$project: {_id: 0, moeda: "$_id", economia_20_porcento: {
    $multiply: ["$salarios_alvo", NumberDecimal("0.20")]
  }}}
]));

// 10.7 — ausentes ou vazios; o modelo atual pode exigir funcionario_id no schema.
mostrar("Vendas sem vendedor", momento.vendas.find({
  $or: [{funcionario_id: null}, {funcionario_id: {$exists: false}}]
}));

// 10.8 — MongoDB não cria chaves estrangeiras: procure referências sem funcionário.
mostrar("Vendas com vendedor inexistente", momento.vendas.aggregate([
  {$lookup: {from: "funcionarios", localField: "funcionario_id", foreignField: "_id", as: "funcionario"}},
  {$match: {funcionario: {$size: 0}}},
  {$project: {_id: 1, funcionario_id: 1, data_venda: 1}}
]));

// 10.9 — variação de preço unitário histórico acima de 10%, por produto/moeda.
mostrar("Variação de preço maior que 10%", momento.vendas.aggregate([
  {$match: {status_venda: "CONCLUIDA"}},
  {$group: {_id: {produto_id: "$produto_id", moeda: "$moeda"},
    menor: {$min: "$preco_unitario"}, maior: {$max: "$preco_unitario"}}},
  {$match: {$expr: {$and: [
    {$gt: ["$menor", NumberDecimal("0.00")]},
    {$gt: [{$divide: [{$subtract: ["$maior", "$menor"]}, "$menor"]}, 0.10]}
  ]}}},
  {$lookup: {from: "produtos", localField: "_id.produto_id", foreignField: "_id", as: "produto"}},
  {$unwind: "$produto"},
  {$project: {produto: "$produto.nome", moeda: "$_id.moeda", menor: 1, maior: 1,
    variacao: {$multiply: [100, {$divide: [{$subtract: ["$maior", "$menor"]}, "$menor"]}]}}},
  {$sort: {variacao: -1}}
]));

// 10.10 — uma agregação de saída única para funcionários, folha, departamentos,
// escritórios, faturamento histórico por moeda e produto mais vendido.
mostrar("Dashboard executivo", momento.funcionarios.aggregate([
  {$group: {_id: {$ifNull: ["$moeda_salario", "USD"]},
    funcionarios: {$sum: 1}, folha: {$sum: "$salario"}}},
  {$group: {_id: null, total_funcionarios: {$sum: "$funcionarios"},
    folha_por_moeda: {$push: {moeda: "$_id", total: "$folha"}}}},
  {$lookup: {from: "departamentos", pipeline: [{$count: "n"}], as: "d"}},
  {$lookup: {from: "escritorios", pipeline: [{$count: "n"}], as: "e"}},
  {$lookup: {
    from: "vendas",
    pipeline: [
      {$match: {status_venda: "CONCLUIDA"}},
      {$lookup: {from: "produtos", localField: "produto_id", foreignField: "_id", as: "produto"}},
      {$unwind: "$produto"},
      {$facet: {
        faturamento: [
          {$group: {_id: "$moeda",
            total: {$sum: {$multiply: ["$quantidade", "$preco_unitario"]}}}},
          {$group: {_id: null, moedas: {$push: {moeda: "$_id", total: "$total"}}}},
          {$project: {_id: 0, moedas: 1}}
        ],
        produto_mais_vendido: [
          {$group: {_id: "$produto_id", unidades: {$sum: "$quantidade"}}},
          {$sort: {unidades: -1, _id: 1}},
          {$limit: 1},
          {$lookup: {from: "produtos", localField: "_id", foreignField: "_id", as: "produto"}},
          {$unwind: "$produto"},
          {$project: {_id: 0, nome: "$produto.nome", unidades: 1}}
        ]
      }}
    ],
    as: "v"
  }},
  {$project: {_id: 0, total_funcionarios: 1, folha_por_moeda: 1,
    total_departamentos: {$ifNull: [{$arrayElemAt: ["$d.n", 0]}, 0]},
    total_escritorios: {$ifNull: [{$arrayElemAt: ["$e.n", 0]}, 0]},
    faturamento_historico_por_moeda: {$ifNull: [{$arrayElemAt: ["$v.faturamento.moedas", 0]}, []]},
    produto_mais_vendido: {$ifNull: [{$arrayElemAt: ["$v.produto_mais_vendido", 0]}, []]}}}
]));
