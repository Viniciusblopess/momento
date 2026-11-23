"""Generate the MongoDB seed from the SQL source. Python standard library only."""
from pathlib import Path
from decimal import Decimal
import json
import re
import sqlite3

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent.parent / 'Tabelas/8_MOMENTO/0_Base.sql'


def money(value):
    return None if value is None else {'$numberDecimal': str(Decimal(str(value)).quantize(Decimal('0.01')))}


def date(value):
    # The source has no timezone. UTC is the documented seed convention.
    return {'$date': value.replace(' ', 'T') + ('T00:00:00' if len(value) == 10 else '') + '.000Z'}


def dump(value):
    return json.dumps(value, ensure_ascii=False, indent=4, allow_nan=False)


def schema(values, field=''):
    """Describe the seed shape, allowing nullable SQL fields even when populated."""
    nullable = {'telefone', 'gerente_id', 'escritorio_id', 'cep', 'origem', 'detalhes',
                'salario_minimo', 'salario_maximo', 'primeiro_nome', 'source_row_id'}
    null_only_types = {'source_row_id': 'int'}
    present = [v for v in values if v is not None]
    if not present:
        kind = null_only_types.get(field, 'string')
    elif isinstance(present[0], dict) and '$date' in present[0]:
        kind = 'date'
    elif isinstance(present[0], dict) and '$numberDecimal' in present[0]:
        kind = 'decimal'
    elif isinstance(present[0], dict):
        keys = list(present[0])
        return {'bsonType': 'object', 'required': keys, 'additionalProperties': False,
                'properties': {k: schema([v[k] for v in present], k) for k in keys}}
    elif isinstance(present[0], list):
        items = [item for array in present for item in array]
        return {'bsonType': 'array', 'items': schema(items)}
    elif isinstance(present[0], bool):
        kind = 'bool'
    elif isinstance(present[0], int):
        kind = 'int'
    else:
        kind = 'string'
    result = {'bsonType': [kind, 'null'] if None in values or field in nullable else kind}
    if kind == 'decimal':
        result['minimum'] = {'$numberDecimal': '0.00'}
    if field == 'quantidade':
        result['minimum'] = 1
    if field == 'status':
        result['enum'] = ['REGISTRADO', 'SUCESSO', 'FALHA', 'BLOQUEADO']
    return result


def build():
    sql = SOURCE.read_text(encoding='utf-8')
    sql = re.sub(r'^(?:DROP DATABASE|CREATE DATABASE|USE ).*;\s*', '', sql, flags=re.M)
    sql = re.sub(r'INT (?:PRIMARY KEY AUTO_INCREMENT|AUTO_INCREMENT PRIMARY KEY)',
                 'INTEGER PRIMARY KEY AUTOINCREMENT', sql)
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys = ON')
    db.executescript(sql)
    assert not db.execute('PRAGMA foreign_key_check').fetchall()

    def rows(table):
        return [dict(r) for r in db.execute('SELECT * FROM ' + table)]

    supplies = rows('suprimentos')
    offices = [dict(_id=r['escritorio_id'], nome=r['escritorio_nome'], endereco=r['endereco'],
                    cep=r['cep'], cidade=r['cidade'], estado_provincia=r['estado_provincia'],
                    pais_id=r['pais_id'], suprimentos=[
                        dict(_id=s['suprimento_id'], referencia_compra=s['referencia_compra'],
                             nome=s['suprimento_nome'], quantidade=s['quantidade_estoque'],
                             custo_unitario=money(s['custo_unitario']), moeda=s['moeda'],
                             data_compra=date(s['data_compra']))
                        for s in supplies if s['escritorio_id'] == r['escritorio_id']])
               for r in rows('escritorios')]
    employees = []
    employee_rows = rows('funcionarios')
    dependents = rows('dependentes')
    for r in employee_rows:
        doc = {('_id' if k == 'funcionario_id' else k): v for k, v in r.items()}
        doc['salario'] = money(r['salario'])
        doc['data_contratacao'] = date(r['data_contratacao'])
        doc['dependentes'] = [dict(_id=d['dependente_id'], primeiro_nome=d['primeiro_nome'],
                                  sobrenome=d['sobrenome'], relacionamento=d['relacionamento'])
                              for d in dependents if d['funcionario_id'] == r['funcionario_id']]
        employees.append(doc)
    people = {r['funcionario_id']: r for r in employee_rows}
    channels = {r['canal_venda_id']: r['nome'] for r in rows('canais_venda')}
    sale_statuses = {r['status_venda_id']: r['nome'] for r in rows('status_venda')}
    audit_modules = {r['modulo_auditoria_id']: r['nome'] for r in rows('modulos_auditoria')}
    audit_statuses = {r['status_auditoria_id']: r['nome'] for r in rows('status_auditoria')}
    categories = {r['categoria_id']: r['categoria_nome'] for r in rows('categorias_produto')}
    sales_headers = {r['venda_id']: r for r in rows('vendas')}
    sales = []
    for item in rows('itens_venda'):
        sale = sales_headers[item['venda_id']]
        sales.append(dict(
            _id=item['item_venda_id'], venda_id=item['venda_id'],
            referencia_origem=sale['referencia_origem'], numero_item=item['numero_item'],
            produto_id=item['produto_id'], quantidade=item['quantidade'],
            preco_unitario=money(item['preco_unitario']), moeda=item['moeda'],
            source_row_id=item['source_row_id'], data_venda=date(sale['data_venda']),
            funcionario_id=sale['funcionario_id'], canal_venda_id=sale['canal_venda_id'],
            canal=channels[sale['canal_venda_id']],
            status_venda_id=sale['status_venda_id'],
            status_venda=sale_statuses[sale['status_venda_id']]
        ))
    audit_logs = []
    for event in rows('audit_log'):
        person = people.get(event['funcionario_id'])
        author = None if person is None else dict(
            primeiro_nome=person['primeiro_nome'],
            sobrenome=person['sobrenome'],
            email=person['email'])
        audit_logs.append(dict(
            _id=event['log_id'], acao=event['log_acao'], data=date(event['log_ts']),
            modulo_id=event['modulo_auditoria_id'],
            modulo=audit_modules[event['modulo_auditoria_id']],
            status_id=event['status_auditoria_id'],
            status=audit_statuses[event['status_auditoria_id']],
            origem=event['log_origem'], detalhes=event['log_detalhes'],
            funcionario_id=event['funcionario_id'], autor=author))
    collections = [
        ('1_escritorios', 'escritorios', offices),
        ('2_departamentos', 'departamentos', [dict(
            _id=r['departamento_id'], nome=r['departamento_nome'],
            educacional=bool(r['educacional']), escritorio_id=r['escritorio_id'])
            for r in rows('departamentos')]),
        ('3_funcionarios', 'funcionarios', employees),
        ('4_vendas', 'vendas', sales),
        ('5_log', 'log', audit_logs),
        ('6_produtos', 'produtos', [dict(
            _id=r['produto_id'], sku=r['sku'], nome=r['produto_nome'],
            categoria_id=r['categoria_id'], categoria=categories[r['categoria_id']],
            preco_unitario=money(r['preco_catalogo']), moeda=r['moeda'],
            ativo=bool(r['ativo'])) for r in rows('produtos')]),
        ('7_paises', 'paises', [dict(_id=r['pais_id'], nome=r['pais_nome'], regiao_id=r['regiao_id']) for r in rows('paises')]),
        ('8_regioes', 'regioes', [dict(_id=r['regiao_id'], nome=r['regiao_nome']) for r in rows('regioes')]),
        ('9_cargos', 'cargos', [dict(_id=r['cargo_id'], nome=r['cargo_nome'], salario_minimo=money(r['min_salario']), salario_maximo=money(r['max_salario'])) for r in rows('cargos')]),
    ]
    # Every source row exported by this nine-collection document model is represented.
    assert sum(len(o['suprimentos']) for o in offices) == len(supplies)
    assert sum(len(f['dependentes']) for f in employees) == len(dependents)
    assert len(sales) == len(rows('itens_venda'))
    assert {s['produto_id'] for s in sales} <= {p['_id'] for p in collections[5][2]}
    assert {s['funcionario_id'] for s in sales} <= {f['_id'] for f in employees}
    db.close()
    return collections


def main():
    collections = build()
    config = []
    indexes = {'funcionarios': [({'email': 1}, {'unique': True}), ({'departamento_id': 1}, {}), ({'cargo_id': 1}, {}), ({'gerente_id': 1}, {})],
               'departamentos': [({'escritorio_id': 1}, {})], 'escritorios': [({'pais_id': 1}, {})],
               'paises': [({'regiao_id': 1}, {})],
               'vendas': [({'funcionario_id': 1, 'data_venda': -1}, {}), ({'produto_id': 1}, {}), ({'data_venda': -1}, {})],
               'log': [({'funcionario_id': 1, 'data': -1}, {}), ({'status': 1, 'data': -1}, {}), ({'modulo': 1, 'data': -1}, {}), ({'data': -1}, {})]}
    for stem, name, documents in collections:
        text = dump(documents)
        (ROOT / (stem + '.json')).write_text(text + '\n', encoding='utf-8')
        # EJSON.parse creates BSON dates and Decimal128 rather than ordinary objects.
        operation = "updateOne: {filter: {_id: doc._id}, update: {$setOnInsert: doc}, upsert: true}" if name == 'log' else "replaceOne: {filter: {_id: doc._id}, replacement: doc, upsert: true}"
        script = ('// Gerado por gerar_dados.py. Nao editar manualmente.\n'
                  '(() => {\n  const docs = EJSON.parse(require("fs").readFileSync("' + stem + '.json", "utf8"));\n'
                  '  db.getSiblingDB("momento").getCollection("' + name + '").bulkWrite(\n'
                  '    docs.map(doc => ({' + operation + '})), {ordered: true});\n})();\n')
        (ROOT / (stem + '.js')).write_text(script, encoding='utf-8')
        config.append(dict(nome=name, schema=schema(documents), indices=indexes.get(name, [])))
        assert json.loads((ROOT / (stem + '.json')).read_text(encoding='utf-8')) == documents
        print(name, len(documents))
    setup = '''// Gerado por gerar_dados.py. Validacao estrita e indices.
(() => {
  const target = db.getSiblingDB("momento");
  const config = EJSON.parse(require("fs").readFileSync("configuracao.json", "utf8"));
  for (const entry of config) {
    const options = {validator: {$jsonSchema: entry.schema}, validationLevel: "strict", validationAction: "error"};
    if (target.getCollectionNames().includes(entry.nome)) {
      assert.commandWorked(target.runCommand({collMod: entry.nome, ...options}));
    } else {
      target.createCollection(entry.nome, options);
    }
    for (const [keys, options] of entry.indices) target.getCollection(entry.nome).createIndex(keys, options);
  }
})();
'''
    (ROOT / 'configuracao.json').write_text(dump(config) + '\n', encoding='utf-8')
    (ROOT / '0_configurar.js').write_text(setup, encoding='utf-8')
    files = ['0_configurar.js'] + [stem + '.js' for stem, _, _ in collections]
    (ROOT / 'importar.js').write_text('// Execute nesta pasta: mongosh --file importar.js\n' + '\n'.join('load(' + json.dumps(f) + ');' for f in files) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
