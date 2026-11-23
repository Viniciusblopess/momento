// Exemplos de escrita para os exercícios MongoDB. Exige replica set para transações.
// O fluxo aborta a transação no final: revise as saídas e substitua abortTransaction
// por commitTransaction somente quando quiser persistir as alterações.
const sessaoMomento = db.getMongo().startSession();
const m = sessaoMomento.getDatabase("momento");
const proximoId = nomeColecao => {
  const cursor = m.getCollection(nomeColecao).find({}, {_id: 1}).sort({_id: -1}).limit(1);
  return cursor.hasNext() ? cursor.next()._id + 1 : 1;
};

sessaoMomento.startTransaction();
try {
  const escritorioWayne = m.escritorios.findOne({nome: "Wayne Offices"});
  const departamentoTech = m.departamentos.findOne({nome: /Tecnologia/i});
  if (!escritorioWayne || !departamentoTech) {
    throw new Error("Wayne Offices ou departamento de Tecnologia não encontrado.");
  }

  // 6.1: cria Inovações se ainda não existir em Wayne Offices.
  let inovacoes = m.departamentos.findOne({
    nome: "Inovações", escritorio_id: escritorioWayne._id
  });
  if (!inovacoes) {
    inovacoes = {
      _id: proximoId("departamentos"),
      nome: "Inovações",
      educacional: false,
      escritorio_id: escritorioWayne._id
    };
    m.departamentos.insertOne(inovacoes);
  }

  // 6.2: regra reprodutível de exemplo — duas pessoas ativas contratadas mais
  // recentemente, exceto Bruce, cuja promoção é tratada em separado.
  const transferidos = m.funcionarios.find({
    departamento_id: departamentoTech._id,
    status_funcionario_id: 1,
    email: {$ne: "bruce.ernst@momento.org"}
  }, {_id: 1}).sort({data_contratacao: -1, _id: -1}).limit(2).toArray();
  if (transferidos.length !== 2) {
    throw new Error("Não há duas pessoas ativas elegíveis para transferência.");
  }
  m.funcionarios.updateMany(
    {_id: {$in: transferidos.map(f => f._id)}},
    {$set: {departamento_id: inovacoes._id}}
  );

  // 6.3: aumento para quem permaneceu em Tecnologia.
  m.funcionarios.updateMany(
    {departamento_id: departamentoTech._id},
    {$mul: {salario: NumberDecimal("1.10")}}
  );

  // 6.4: registra cargo e promove Bruce. A base atual tem salário 6.000;
  // o enunciado pede valor final 5.000, que é uma redução, não um aumento.
  let cargoSenior = m.cargos.findOne({nome: "Senior Web Developer"});
  if (!cargoSenior) {
    cargoSenior = {
      _id: proximoId("cargos"),
      nome: "Senior Web Developer",
      salario_minimo: NumberDecimal("4000.00"),
      salario_maximo: NumberDecimal("10000.00")
    };
    m.cargos.insertOne(cargoSenior);
  }
  m.funcionarios.updateOne(
    {email: "bruce.ernst@momento.org"},
    {$set: {cargo_id: cargoSenior._id, salario: NumberDecimal("5000.00")}}
  );

  // 6.5: exemplo segundo o pedido. O modelo não registra moeda/data de compra
  // para subdocumento de suprimento; custo=150 é a hipótese de custo unitário.
  const headsetExistente = m.escritorios.findOne({
    _id: escritorioWayne._id, "suprimentos.nome": "Headsets"
  });
  if (!headsetExistente) {
    const maxSupply = m.escritorios.aggregate([
      {$unwind: "$suprimentos"},
      {$group: {_id: null, maximo: {$max: "$suprimentos._id"}}}
    ]).toArray()[0];
    const novoSuprimentoId = maxSupply ? maxSupply.maximo + 1 : 1;
    m.escritorios.updateOne(
      {_id: escritorioWayne._id},
      {$push: {suprimentos: {
        _id: novoSuprimentoId,
        referencia_compra: "PO-HEADSET-MOMENTO-2026-01",
        nome: "Headsets",
        quantidade: 15,
        custo_unitario: NumberDecimal("150.00"),
        moeda: "USD",
        data_compra: new Date()
      }}}
    );
  }

  // 6.6: aposentadoria simulada por status, preservando vendas, auditoria e histórico.
  m.funcionarios.updateMany(
    {data_contratacao: {$lt: ISODate("1990-01-01")}},
    {$set: {status_funcionario_id: 3}}
  );

  // Cenário internacional 10.1–10.2: novo escritório e departamento.
  const brasil = m.paises.findOne({_id: "BR"});
  if (!brasil) throw new Error("País BR não cadastrado; não invente a referência.");
  let momentoBrasil = m.escritorios.findOne({nome: "Momento Brasil"});
  if (!momentoBrasil) {
    momentoBrasil = {
      _id: proximoId("escritorios"),
      nome: "Momento Brasil",
      endereco: "Av. Paulista, 1000",
      cep: "01310-100",
      cidade: "São Paulo",
      estado_provincia: "São Paulo",
      pais_id: brasil._id,
      suprimentos: [{
        _id: (m.escritorios.aggregate([
          {$unwind: "$suprimentos"},
          {$group: {_id: null, maximo: {$max: "$suprimentos._id"}}}
        ]).toArray()[0] || {maximo: 0}).maximo + 1,
        referencia_compra: "PO-BRASIL-INICIAL-001",
        nome: "Papel", quantidade: 20,
        custo_unitario: NumberDecimal("100.00"), moeda: "BRL",
        data_compra: new Date()
      }]
    };
    m.escritorios.insertOne(momentoBrasil);
  }
  if (!m.departamentos.findOne({nome: "Operações LATAM", escritorio_id: momentoBrasil._id})) {
    m.departamentos.insertOne({
      _id: proximoId("departamentos"),
      nome: "Operações LATAM",
      educacional: false,
      escritorio_id: momentoBrasil._id
    });
  }

  // 10.3 pede você e quatro colegas, mas os nomes/emails reais não foram fornecidos.
  // Insira cinco documentos em funcionarios usando o template 1.1, com IDs, emails,
  // cargos e dados reais; não use placeholders como se fossem pessoas cadastradas.

  print("Pessoas transferidas:");
  printjson(m.funcionarios.find({_id: {$in: transferidos.map(f => f._id)}}).toArray());
  print("Bruce após promoção:");
  printjson(m.funcionarios.findOne({email: "bruce.ernst@momento.org"}));
  print("Departamento Inovações:");
  printjson(m.departamentos.findOne({_id: inovacoes._id}));
  print("Escritório Momento Brasil:");
  printjson(m.escritorios.findOne({_id: momentoBrasil._id}));

  sessaoMomento.abortTransaction();
  print("Transação abortada; nenhuma alteração foi persistida.");
} catch (erro) {
  try { sessaoMomento.abortTransaction(); } catch (_) {}
  print("Transação abortada por erro: " + erro.message);
  throw erro;
} finally {
  sessaoMomento.endSession();
}
