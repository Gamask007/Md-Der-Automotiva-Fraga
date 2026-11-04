// Sistema da Oficina Fraga — telas simples sobre o banco fraga_oficina.
// Uso: node server.js  (ou o atalho "Sistema Oficina Fraga" na Área de Trabalho)
const express = require('express');
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

const PORTA = 8780;
const db = mysql.createPool({
  host: '127.0.0.1', port: 3307, user: 'root', password: '', database: 'fraga_oficina',
  dateStrings: true, decimalNumbers: true, connectionLimit: 5,
});

const app = express();
app.use(express.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname, 'public')));

// ---------------------------------------------------------------- utilidades
const h = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const reais = (v) => Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
const dataBR = (s) => {
  if (!s) return '';
  const [d, t] = String(s).split(' ');
  const [a, m, dia] = d.split('-');
  return `${dia}/${m}/${a}${t ? ' ' + t.slice(0, 5) : ''}`;
};
const soDigitos = (s) => String(s || '').replace(/\D/g, '');
const placaLimpa = (s) => String(s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');

const STATUS = {
  aberta: ['Aberta — montar orçamento', 'cinza'],
  aguardando_aprovacao: ['Esperando o cliente aprovar', 'amarelo'],
  em_execucao: ['Em serviço', 'azul'],
  pronta: ['Pronto para retirar', 'verde'],
  entregue: ['Entregue', 'neutro'],
  cancelada: ['Cancelada', 'vermelho'],
};
const saudacao = () => { const hora = new Date().getHours(); return hora < 12 ? 'Bom dia' : hora < 18 ? 'Boa tarde' : 'Boa noite'; };
const selo = (s) => `<span class="selo ${STATUS[s]?.[1]}">${h(STATUS[s]?.[0] || s)}</span>`;
const FORMAS = { pix: 'Pix', dinheiro: 'Dinheiro', debito: 'Cartão de débito', credito: 'Cartão de crédito' };

function pagina(titulo, corpo, aviso) {
  return `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>${h(titulo)} · Oficina Fraga</title>
<link rel="stylesheet" href="/estilo.css"></head><body>
<header><a class="marca" href="/">🔧 Oficina Fraga</a>
<nav><a href="/">Início</a><a href="/clientes">Clientes</a><a href="/relatorios">Relatórios</a></nav>
<form class="busca" action="/buscar"><input name="placa" placeholder="Buscar placa (ex.: ABC1D23)" autocomplete="off"><button>Buscar</button></form>
</header><main>${aviso ? `<div class="aviso ${aviso.tipo}">${h(aviso.texto)}</div>` : ''}${corpo}</main></body></html>`;
}

// traduz erros do MySQL para frases que o dono entende
function erroAmigavel(e) {
  const m = String(e.sqlMessage || e.message || '');
  if (e.code === 'ER_DUP_ENTRY') {
    if (m.includes('placa')) return 'Já existe um carro cadastrado com essa placa.';
    if (m.includes('cpf_cnpj')) return 'Já existe um cliente com esse CPF/CNPJ.';
    return 'Esse cadastro já existe.';
  }
  if (m.includes('RN10')) return 'Não há peças suficientes no estoque para aprovar este serviço. Confira o estoque ou troque a peça.';
  const regras = {
    ck_veiculo_placa: 'Placa inválida. Use o formato ABC1D23 ou ABC1234.',
    ck_cliente_doc: 'CPF deve ter 11 números (ou CNPJ 14 números).',
    ck_cliente_cep: 'CEP deve ter 8 números.',
    ck_veiculo_ano: 'Ano do carro inválido.',
    ck_pagamento_parcelas: 'Parcelamento só no cartão de crédito (até 12x).',
    ck_pagamento_valor: 'O valor do pagamento precisa ser maior que zero.',
  };
  for (const [k, v] of Object.entries(regras)) if (m.includes(k)) return v;
  if (e.code === 'ER_ROW_IS_REFERENCED_2') return 'Não dá para apagar: existe histórico ligado a este cadastro.';
  if (e.code === 'ECONNREFUSED') return 'O banco de dados está desligado. Feche e abra o sistema pelo ícone da Área de Trabalho.';
  return 'Não foi possível salvar: ' + m;
}

const voltar = (res, url, texto, tipo = 'ok') =>
  res.redirect(url + (url.includes('?') ? '&' : '?') + 'msg=' + encodeURIComponent(texto) + '&tipo=' + tipo);
const avisoDe = (req) => (req.query.msg ? { texto: req.query.msg, tipo: req.query.tipo || 'ok' } : null);
const rota = (fn) => (req, res) => fn(req, res).catch((e) => {
  console.error(e);
  res.status(500).send(pagina('Erro', `<h1>Algo deu errado</h1><p>${h(erroAmigavel(e))}</p><p><a href="javascript:history.back()">← Voltar</a></p>`));
});

// ---------------------------------------------------------------- início
app.get('/', rota(async (req, res) => {
  const [[r]] = await db.query(`
    SELECT SUM(status IN ('aberta','aguardando_aprovacao','em_execucao')) AS na_oficina,
           SUM(status = 'pronta') AS prontos,
           SUM(DATE(data_entrada) = CURDATE()) AS hoje
    FROM ordem_servico`);
  const [[rec]] = await db.query(`
    SELECT COALESCE(SUM(t.saldo_devedor),0) AS a_receber FROM vw_total_os t
    JOIN ordem_servico os ON os.id_os = t.id_os WHERE os.status IN ('pronta','entregue') AND t.saldo_devedor > 0`);
  const [[est]] = await db.query(`SELECT COUNT(*) AS n FROM vw_saldo_estoque WHERE saldo < estoque_minimo`);
  const [abertas] = await db.query(`
    SELECT os.id_os, os.numero_os, os.status, os.data_entrada, os.data_previsao, os.cliente_avisado,
           v.placa, CONCAT(v.marca,' ',v.modelo) AS carro, c.nome, c.telefone
    FROM ordem_servico os JOIN veiculo v ON v.id_veiculo = os.id_veiculo JOIN cliente c ON c.id_cliente = v.id_cliente
    WHERE os.status NOT IN ('entregue','cancelada') ORDER BY FIELD(os.status,'pronta','em_execucao','aguardando_aprovacao','aberta'), os.data_entrada`);
  const linhas = abertas.map((o) => `<tr onclick="location='/os/${o.id_os}'">
    <td><b>${o.numero_os}</b></td><td>${selo(o.status)}${o.status === 'pronta' && !o.cliente_avisado ? ' <span class="selo vermelho">avisar cliente</span>' : ''}</td>
    <td><b>${h(o.placa)}</b><br><small>${h(o.carro)}</small></td><td>${h(o.nome)}<br><small>${h(o.telefone)}</small></td>
    <td>${dataBR(o.data_entrada)}</td><td>${dataBR(o.data_previsao)}</td></tr>`).join('');
  res.send(pagina('Início', `
    <h1>${saudacao()}! Veja como está a oficina</h1>
    <div class="cartoes">
      <div class="cartao"><span>${r.na_oficina || 0}</span>carros em serviço ou orçamento</div>
      <div class="cartao verde"><span>${r.prontos || 0}</span>prontos para retirar</div>
      <div class="cartao"><span>${r.hoje || 0}</span>entraram hoje</div>
      <a class="cartao amarelo" href="/relatorios/G07"><span>${reais(rec.a_receber)}</span>a receber de clientes</a>
      <a class="cartao vermelho" href="/relatorios/G01"><span>${est.n}</span>peças abaixo do mínimo</a>
    </div>
    <div class="acoes"><a class="botao grande" href="/clientes/novo">+ Cliente novo</a>
      <span class="dica">Cliente que já veio? Digite a placa na busca lá em cima e clique em "Abrir ordem de serviço".</span></div>
    <h2>Carros na oficina agora</h2>
    ${abertas.length ? `<table class="clicavel"><tr><th>OS</th><th>Situação</th><th>Carro</th><th>Cliente</th><th>Entrada</th><th>Previsão</th></tr>${linhas}</table>`
                     : '<p>Nenhum carro na oficina no momento.</p>'}`, avisoDe(req)));
}));

// ---------------------------------------------------------------- busca por placa
app.get('/buscar', rota(async (req, res) => {
  const placa = placaLimpa(req.query.placa);
  if (!placa) return res.redirect('/');
  const [vs] = await db.query('SELECT id_veiculo FROM veiculo WHERE placa LIKE ?', [placa + '%']);
  if (vs.length === 1) return res.redirect('/veiculo/' + vs[0].id_veiculo);
  if (vs.length > 1) return res.redirect('/clientes?q=' + encodeURIComponent(placa));
  res.send(pagina('Placa não encontrada', `<h1>Nenhum carro com a placa ${h(placa)}</h1>
    <p>É a primeira vez desse carro na oficina?</p>
    <a class="botao grande" href="/clientes/novo?placa=${h(placa)}">Cadastrar cliente e carro</a>
    <p class="dica">Se o dono já é cliente (outro carro), procure o nome em <a href="/clientes">Clientes</a> e adicione o carro lá.</p>`));
}));

// ---------------------------------------------------------------- veículo
app.get('/veiculo/:id', rota(async (req, res) => {
  const [[v]] = await db.query(`SELECT v.*, c.nome, c.telefone, c.id_cliente FROM veiculo v JOIN cliente c USING (id_cliente) WHERE v.id_veiculo = ?`, [req.params.id]);
  if (!v) return res.redirect('/');
  const [oss] = await db.query(`SELECT os.*, t.total_os FROM ordem_servico os JOIN vw_total_os t USING (id_os) WHERE id_veiculo = ? ORDER BY data_entrada DESC`, [v.id_veiculo]);
  const emAberto = oss.find((o) => !['entregue', 'cancelada'].includes(o.status));
  res.send(pagina(v.placa, `
    <h1>${h(v.placa)} — ${h(v.marca)} ${h(v.modelo)} ${h(v.motor || '')} ${v.ano}</h1>
    <p>Dono: <a href="/clientes/${v.id_cliente}"><b>${h(v.nome)}</b></a> · ${h(v.telefone)} · Última km registrada: ${Number(v.km_atual).toLocaleString('pt-BR')}</p>
    <div class="acoes">${emAberto ? `<a class="botao grande" href="/os/${emAberto.id_os}">Ver a OS em aberto (nº ${emAberto.numero_os})</a>`
      : `<a class="botao grande" href="/os/nova?veiculo=${v.id_veiculo}">Abrir ordem de serviço</a>`}</div>
    <h2>Histórico deste carro</h2>
    ${oss.length ? `<table class="clicavel"><tr><th>OS</th><th>Entrada</th><th>Km</th><th>Problema</th><th>Situação</th><th>Total</th></tr>
      ${oss.map((o) => `<tr onclick="location='/os/${o.id_os}'"><td>${o.numero_os}</td><td>${dataBR(o.data_entrada)}</td><td>${Number(o.km_entrada).toLocaleString('pt-BR')}</td>
        <td>${h(o.problema_relatado)}</td><td>${selo(o.status)}</td><td>${reais(o.total_os)}</td></tr>`).join('')}</table>`
      : '<p>Este carro ainda não teve nenhuma OS.</p>'}`, avisoDe(req)));
}));

// ---------------------------------------------------------------- clientes
app.get('/clientes', rota(async (req, res) => {
  const q = String(req.query.q || '').trim();
  const [cs] = await db.query(`
    SELECT c.id_cliente, c.nome, c.telefone, GROUP_CONCAT(v.placa ORDER BY v.placa SEPARATOR ', ') AS placas
    FROM cliente c LEFT JOIN veiculo v USING (id_cliente)
    WHERE ? = '' OR c.nome LIKE ? OR c.cpf_cnpj LIKE ? OR v.placa LIKE ? OR c.telefone LIKE ?
    GROUP BY c.id_cliente ORDER BY c.nome LIMIT 200`, [q, `%${q}%`, `%${q}%`, `%${placaLimpa(q) || q}%`, `%${q}%`]);
  res.send(pagina('Clientes', `<h1>Clientes</h1>
    <form class="filtro"><input name="q" value="${h(q)}" placeholder="Nome, CPF, telefone ou placa"><button>Procurar</button>
    <a class="botao" href="/clientes/novo">+ Cliente novo</a></form>
    <table class="clicavel"><tr><th>Nome</th><th>Telefone</th><th>Carros</th></tr>
    ${cs.map((c) => `<tr onclick="location='/clientes/${c.id_cliente}'"><td>${h(c.nome)}</td><td>${h(c.telefone)}</td><td>${h(c.placas || '—')}</td></tr>`).join('')}</table>
    <p class="dica">${cs.length} cliente(s) ${q ? 'encontrado(s)' : 'mostrados'}.</p>`, avisoDe(req)));
}));

const camposCarro = (placa = '') => `
  <fieldset><legend>Carro</legend>
  <label>Placa*<input name="placa" required value="${h(placa)}" placeholder="ABC1D23" style="text-transform:uppercase"></label>
  <label>Marca*<input name="marca" required placeholder="Fiat, VW, Chevrolet..."></label>
  <label>Modelo*<input name="modelo" required placeholder="Uno, Gol, Onix..."></label>
  <label>Ano*<input name="ano" type="number" required min="1950" max="2100" placeholder="2018"></label>
  <label>Motor<input name="motor" placeholder="1.0, 1.6..."></label>
  <label>Km atual<input name="km_atual" type="number" min="0" placeholder="45000"></label></fieldset>`;

app.get('/clientes/novo', (req, res) => {
  res.send(pagina('Cliente novo', `<h1>Cadastrar cliente e carro</h1>
  <form method="post" action="/clientes" class="formulario">
  <fieldset><legend>Cliente</legend>
  <label>Nome completo*<input name="nome" required></label>
  <label>CPF ou CNPJ* <small>só os números</small><input name="doc" required inputmode="numeric"></label>
  <label>Telefone / WhatsApp*<input name="telefone" required placeholder="(11) 90000-0000"></label>
  <label>E-mail<input name="email" type="email"></label>
  <label>Rua*<input name="logradouro" required></label>
  <label>Número*<input name="numero" required></label>
  <label>Bairro*<input name="bairro" required></label>
  <label>CEP*<input name="cep" required inputmode="numeric" placeholder="08270700"></label>
  <label class="check"><input type="checkbox" name="lgpd" value="1" checked> O cliente autorizou guardar os dados dele (LGPD)</label>
  </fieldset>${camposCarro(req.query.placa)}
  <button class="botao grande">Salvar cadastro</button></form>`, avisoDe(req)));
});

function formatarDoc(doc) {
  const d = soDigitos(doc);
  if (d.length === 11) return ['F', d.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4')];
  if (d.length === 14) return ['J', d.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5')];
  return ['F', doc];
}
const cepFormatado = (c) => soDigitos(c).replace(/(\d{5})(\d{3})/, '$1-$2');
const dadosCarro = (b) => [placaLimpa(b.placa), b.marca.trim(), b.modelo.trim(), Number(b.ano), b.motor?.trim() || null, Number(b.km_atual || 0)];

app.post('/clientes', rota(async (req, res) => {
  const b = req.body;
  const [tipo, doc] = formatarDoc(b.doc);
  const con = await db.getConnection();
  try {
    await con.beginTransaction();
    const [c] = await con.query(`INSERT INTO cliente (nome, tipo_pessoa, cpf_cnpj, telefone, email, logradouro, numero, bairro, cep, data_cadastro, consentimento_lgpd)
      VALUES (?,?,?,?,?,?,?,?,?,CURDATE(),?)`, [b.nome.trim(), tipo, doc, b.telefone.trim(), b.email || null, b.logradouro.trim(), b.numero.trim(), b.bairro.trim(), cepFormatado(b.cep), b.lgpd ? 1 : 0]);
    const [v] = await con.query('INSERT INTO veiculo (id_cliente, placa, marca, modelo, ano, motor, km_atual) VALUES (?,?,?,?,?,?,?)', [c.insertId, ...dadosCarro(b)]);
    await con.commit();
    voltar(res, '/veiculo/' + v.insertId, 'Cliente e carro cadastrados! Agora é só abrir a ordem de serviço.');
  } catch (e) {
    await con.rollback();
    voltar(res, '/clientes/novo?placa=' + encodeURIComponent(b.placa || ''), erroAmigavel(e) + ' (os dados digitados precisam ser preenchidos de novo)', 'erro');
  } finally { con.release(); }
}));

app.get('/clientes/:id', rota(async (req, res) => {
  const [[c]] = await db.query('SELECT * FROM cliente WHERE id_cliente = ?', [req.params.id]);
  if (!c) return res.redirect('/clientes');
  const [vs] = await db.query('SELECT * FROM veiculo WHERE id_cliente = ? ORDER BY placa', [c.id_cliente]);
  res.send(pagina(c.nome, `<h1>${h(c.nome)}</h1>
    <p>${h(c.telefone)} ${c.email ? '· ' + h(c.email) : ''}<br>${h(c.logradouro)}, ${h(c.numero)} — ${h(c.bairro)} · CEP ${h(c.cep)}<br>
    <small>Cliente desde ${dataBR(c.data_cadastro)} · ${c.consentimento_lgpd ? 'autorizou guardar os dados (LGPD)' : '<b>sem autorização LGPD registrada</b>'}</small></p>
    <h2>Carros</h2>
    ${vs.length ? `<table class="clicavel"><tr><th>Placa</th><th>Carro</th><th>Ano</th></tr>${vs.map((v) => `<tr onclick="location='/veiculo/${v.id_veiculo}'"><td><b>${h(v.placa)}</b></td><td>${h(v.marca)} ${h(v.modelo)} ${h(v.motor || '')}</td><td>${v.ano}</td></tr>`).join('')}</table>` : '<p>Nenhum carro no nome deste cliente.</p>'}
    <details><summary class="botao">+ Adicionar outro carro</summary>
    <form method="post" action="/clientes/${c.id_cliente}/veiculos" class="formulario">${camposCarro()}<button class="botao grande">Salvar carro</button></form></details>`, avisoDe(req)));
}));

app.post('/clientes/:id/veiculos', rota(async (req, res) => {
  try {
    const [v] = await db.query('INSERT INTO veiculo (id_cliente, placa, marca, modelo, ano, motor, km_atual) VALUES (?,?,?,?,?,?,?)', [req.params.id, ...dadosCarro(req.body)]);
    voltar(res, '/veiculo/' + v.insertId, 'Carro cadastrado!');
  } catch (e) { voltar(res, '/clientes/' + req.params.id, erroAmigavel(e), 'erro'); }
}));

// ---------------------------------------------------------------- ordem de serviço
const funcionarios = async (filtro) => (await db.query(`SELECT id_funcionario, nome FROM funcionario WHERE ativo = 1 AND ${filtro} ORDER BY nome`))[0];
const opcoes = (lista, sel) => lista.map((f) => `<option value="${f.id_funcionario}" ${f.id_funcionario == sel ? 'selected' : ''}>${h(f.nome)}</option>`).join('');

app.get('/os/nova', rota(async (req, res) => {
  const [[v]] = await db.query('SELECT v.*, c.nome FROM veiculo v JOIN cliente c USING (id_cliente) WHERE id_veiculo = ?', [req.query.veiculo]);
  if (!v) return res.redirect('/');
  const atendentes = await funcionarios('pode_editar_cadastro = 1');
  res.send(pagina('Nova OS', `<h1>Abrir ordem de serviço — ${h(v.placa)}</h1>
    <p>${h(v.marca)} ${h(v.modelo)} de <b>${h(v.nome)}</b></p>
    <form method="post" action="/os" class="formulario"><input type="hidden" name="id_veiculo" value="${v.id_veiculo}">
    <label>O que o cliente relatou?*<textarea name="problema" required rows="3" placeholder="Ex.: barulho ao frear, troca de óleo vencida"></textarea></label>
    <label>Km no painel*<input name="km" type="number" required min="${v.km_atual}" value="${v.km_atual}"></label>
    <label>Previsão de entrega<input name="previsao" type="date"></label>
    <label>Quem está atendendo*<select name="atendente">${opcoes(atendentes)}</select></label>
    <button class="botao grande">Abrir OS</button></form>`));
}));

app.post('/os', rota(async (req, res) => {
  const b = req.body;
  const [[{ prox }]] = await db.query('SELECT COALESCE(MAX(numero_os), 25000) + 1 AS prox FROM ordem_servico');
  const [r] = await db.query(`INSERT INTO ordem_servico (numero_os, id_veiculo, id_atendente, km_entrada, problema_relatado, data_entrada, data_previsao, status)
    VALUES (?,?,?,?,?,NOW(),?,'aberta')`, [prox, b.id_veiculo, b.atendente, b.km, b.problema.trim(), b.previsao || null]);
  await db.query('UPDATE veiculo SET km_atual = GREATEST(km_atual, ?) WHERE id_veiculo = ?', [b.km, b.id_veiculo]);
  voltar(res, '/os/' + r.insertId, `OS nº ${prox} aberta. Agora adicione os serviços e peças do orçamento.`);
}));

app.get('/os/:id', rota(async (req, res) => {
  const id = req.params.id;
  const [[os]] = await db.query(`
    SELECT os.*, v.placa, v.marca, v.modelo, v.id_veiculo, c.nome, c.telefone, c.id_cliente,
           a.nome AS atendente, m.nome AS mecanico, o.status AS orc_status, o.valor_total AS orc_valor, s.nome AS orcou
    FROM ordem_servico os JOIN veiculo v USING (id_veiculo) JOIN cliente c USING (id_cliente)
    JOIN funcionario a ON a.id_funcionario = os.id_atendente LEFT JOIN funcionario m ON m.id_funcionario = os.id_mecanico
    LEFT JOIN orcamento o ON o.id_os = os.id_os LEFT JOIN funcionario s ON s.id_funcionario = o.id_funcionario
    WHERE os.id_os = ?`, [id]);
  if (!os) return res.redirect('/');
  const [[t]] = await db.query('SELECT * FROM vw_total_os WHERE id_os = ?', [id]);
  const [servs] = await db.query('SELECT i.*, s.nome_servico FROM item_servico i JOIN servico s USING (id_servico) WHERE id_os = ? ORDER BY id_item_servico', [id]);
  const [pecas] = await db.query('SELECT i.*, p.nome_peca FROM item_peca i LEFT JOIN peca p USING (id_peca) WHERE id_os = ? ORDER BY id_item_peca', [id]);
  const [pags] = await db.query('SELECT * FROM pagamento WHERE id_os = ? ORDER BY data_pagamento', [id]);
  const editavel = os.status === 'aberta';

  const itens = [
    ...servs.map((s) => `<tr><td>Serviço</td><td>${h(s.nome_servico)}${s.retrabalho_garantia ? ' <small>(garantia)</small>' : ''}</td><td>${s.quantidade}</td><td>${reais(s.valor_cobrado)}</td><td>${reais(s.quantidade * s.valor_cobrado)}</td>
      <td>${editavel ? `<form method="post" action="/os/${id}/remover"><input type="hidden" name="tipo" value="s"><input type="hidden" name="item" value="${s.id_item_servico}"><button class="link">remover</button></form>` : ''}</td></tr>`),
    ...pecas.map((p) => `<tr><td>Peça ${p.origem === 'cliente' ? '<span class="selo amarelo">do cliente</span>' : ''}</td><td>${h(p.nome_peca || p.descricao_peca_cliente)}</td><td>${p.quantidade}</td><td>${reais(p.valor_unitario)}</td><td>${reais(p.quantidade * p.valor_unitario)}</td>
      <td>${editavel ? `<form method="post" action="/os/${id}/remover"><input type="hidden" name="tipo" value="p"><input type="hidden" name="item" value="${p.id_item_peca}"><button class="link">remover</button></form>` : ''}</td></tr>`),
  ].join('');

  let acoes = '';
  if (editavel) {
    const [catalogo] = await db.query('SELECT id_servico, nome_servico, valor_base FROM servico WHERE ativo = 1 ORDER BY nome_servico');
    const [estoque] = await db.query('SELECT p.id_peca, p.nome_peca, p.valor_venda, e.saldo FROM peca p JOIN vw_saldo_estoque e USING (id_peca) WHERE p.ativo = 1 ORDER BY p.nome_peca');
    const socios = await funcionarios("funcao = 'socio'");
    acoes = `<div class="grade">
      <form method="post" action="/os/${id}/servico" class="caixa"><h3>Adicionar serviço</h3>
        <select name="id_servico" onchange="this.form.valor.value=this.selectedOptions[0].dataset.v">${catalogo.map((s) => `<option value="${s.id_servico}" data-v="${s.valor_base}">${h(s.nome_servico)} — ${reais(s.valor_base)}</option>`).join('')}</select>
        <label>Valor cobrado (R$)<input name="valor" type="number" step="0.01" min="0" value="${catalogo[0]?.valor_base}"></label>
        <button class="botao">Adicionar serviço</button></form>
      <form method="post" action="/os/${id}/peca" class="caixa"><h3>Adicionar peça</h3>
        <select name="id_peca">${estoque.map((p) => `<option value="${p.id_peca}" ${p.saldo <= 0 ? 'disabled' : ''}>${h(p.nome_peca)} — ${reais(p.valor_venda)} (estoque: ${p.saldo})</option>`).join('')}
        <option value="cliente">➜ Peça trazida pelo cliente (sem custo e sem garantia)</option></select>
        <label>Se for do cliente, qual peça?<input name="descricao" placeholder="Ex.: pastilha de freio que o cliente trouxe"></label>
        <label>Quantidade<input name="quantidade" type="number" min="1" value="1"></label>
        <button class="botao">Adicionar peça</button></form>
      <form method="post" action="/os/${id}/orcamento" class="caixa destaque"><h3>Orçamento pronto?</h3>
        <p>Total: <b>${reais(t.total_os)}</b>. Depois de enviar, os itens ficam travados (o valor aprovado é o cobrado).</p>
        <label>Quem fez o orçamento<select name="socio">${opcoes(socios)}</select></label>
        <button class="botao grande" ${servs.length + pecas.length ? '' : 'disabled'}>Enviar orçamento ao cliente</button></form></div>`;
  } else if (os.status === 'aguardando_aprovacao') {
    const mecanicos = await funcionarios("funcao IN ('mecanico','socio')");
    acoes = `<div class="grade">
      <form method="post" action="/os/${id}/aprovar" class="caixa destaque"><h3>O cliente aprovou ${reais(os.orc_valor)}?</h3>
        <label>Mecânico responsável<select name="mecanico">${opcoes(mecanicos)}</select></label>
        <button class="botao grande">Sim, aprovou — começar o serviço</button></form>
      <form method="post" action="/os/${id}/recusar" class="caixa"><h3>O cliente não quis fazer?</h3>
        <button class="botao perigo">Cliente recusou — cancelar OS</button></form></div>`;
  } else if (os.status === 'em_execucao') {
    acoes = `<form method="post" action="/os/${id}/pronta" class="caixa destaque"><h3>O serviço terminou?</h3><button class="botao grande">Marcar como pronto</button></form>`;
  } else if (os.status === 'pronta') {
    acoes = `<div class="grade">
      ${os.cliente_avisado ? '<div class="caixa"><h3>✔ Cliente já foi avisado</h3></div>'
        : `<form method="post" action="/os/${id}/avisado" class="caixa destaque"><h3>Avise o cliente</h3><p>Ligue ou mande WhatsApp para <b>${h(os.telefone)}</b>.</p><button class="botao grande">Já avisei</button></form>`}
      <form method="post" action="/os/${id}/entregar" class="caixa"><h3>Cliente veio buscar?</h3>
        <label>Número da nota fiscal<input name="nf" value="NFSe-${os.numero_os}"></label>
        ${t.saldo_devedor > 0 ? `<p class="alerta">Ainda falta receber ${reais(t.saldo_devedor)}. Se entregar assim, fica como "a receber".</p>` : ''}
        <button class="botao grande">Entregar o carro</button></form></div>`;
  }

  const podePagar = ['em_execucao', 'pronta', 'entregue'].includes(os.status) && t.saldo_devedor > 0;
  const formPagamento = podePagar ? `<form method="post" action="/os/${id}/pagamento" class="caixa"><h3>Receber pagamento</h3>
      <label>Valor (R$)<input name="valor" type="number" step="0.01" min="0.01" max="${t.saldo_devedor}" value="${t.saldo_devedor}"></label>
      <label>Forma<select name="forma" onchange="this.form.parcelas.disabled=this.value!=='credito'">${Object.entries(FORMAS).map(([k, v]) => `<option value="${k}">${v}</option>`).join('')}</select></label>
      <label>Parcelas (só no crédito)<input name="parcelas" type="number" min="1" max="12" value="1" disabled></label>
      <button class="botao">Registrar pagamento</button></form>` : '';

  res.send(pagina('OS ' + os.numero_os, `
    <p><a href="/">← Início</a></p>
    <h1>OS nº ${os.numero_os} ${selo(os.status)}</h1>
    <div class="ficha">
      <div><small>Carro</small><a href="/veiculo/${os.id_veiculo}"><b>${h(os.placa)}</b></a> ${h(os.marca)} ${h(os.modelo)} · ${Number(os.km_entrada).toLocaleString('pt-BR')} km</div>
      <div><small>Cliente</small><a href="/clientes/${os.id_cliente}">${h(os.nome)}</a> · ${h(os.telefone)}</div>
      <div><small>Problema relatado</small>${h(os.problema_relatado)}</div>
      <div><small>Entrada</small>${dataBR(os.data_entrada)} · atendido por ${h(os.atendente)}</div>
      ${os.data_previsao ? `<div><small>Previsão</small>${dataBR(os.data_previsao)}</div>` : ''}
      ${os.mecanico ? `<div><small>Mecânico</small>${h(os.mecanico)}</div>` : ''}
      ${os.orcou ? `<div><small>Orçamento</small>${reais(os.orc_valor)} por ${h(os.orcou)} — ${h(os.orc_status)}</div>` : ''}
      ${os.data_saida ? `<div><small>Saída</small>${dataBR(os.data_saida)} · garantia até ${dataBR(os.garantia_ate)} · NF ${h(os.numero_nota_fiscal || '—')}</div>` : ''}
      ${os.observacoes ? `<div><small>Observações</small>${h(os.observacoes)}</div>` : ''}
    </div>
    <h2>Serviços e peças</h2>
    ${itens ? `<table><tr><th></th><th>Item</th><th>Qtd</th><th>Valor</th><th>Subtotal</th><th></th></tr>${itens}</table>` : '<p>Nenhum item ainda.</p>'}
    <div class="totais"><div>Total <b>${reais(t.total_os)}</b></div><div>Pago <b>${reais(t.total_pago)}</b></div>
      <div class="${t.saldo_devedor > 0 ? 'falta' : ''}">Falta pagar <b>${reais(t.saldo_devedor)}</b></div></div>
    ${acoes}
    ${pags.length ? `<h2>Pagamentos recebidos</h2><table><tr><th>Data</th><th>Forma</th><th>Parcelas</th><th>Valor</th></tr>
      ${pags.map((p) => `<tr><td>${dataBR(p.data_pagamento)}</td><td>${FORMAS[p.forma_pagamento]}</td><td>${p.parcelas}x</td><td>${reais(p.valor_pago)}</td></tr>`).join('')}</table>` : ''}
    ${formPagamento}`, avisoDe(req)));
}));

const estaEm = async (id, status) => (await db.query('SELECT status FROM ordem_servico WHERE id_os = ?', [id]))[0][0]?.status === status;

app.post('/os/:id/servico', rota(async (req, res) => {
  if (!(await estaEm(req.params.id, 'aberta'))) return voltar(res, '/os/' + req.params.id, 'O orçamento já foi enviado; os itens não podem mais mudar.', 'erro');
  await db.query('INSERT INTO item_servico (id_os, id_servico, quantidade, valor_cobrado) VALUES (?,?,1,?)', [req.params.id, req.body.id_servico, Number(req.body.valor || 0)]);
  voltar(res, '/os/' + req.params.id, 'Serviço adicionado.');
}));

app.post('/os/:id/peca', rota(async (req, res) => {
  const id = req.params.id, b = req.body, qtd = Math.max(1, Number(b.quantidade || 1));
  if (!(await estaEm(id, 'aberta'))) return voltar(res, '/os/' + id, 'O orçamento já foi enviado; os itens não podem mais mudar.', 'erro');
  if (b.id_peca === 'cliente') {
    if (!b.descricao?.trim()) return voltar(res, '/os/' + id, 'Escreva qual peça o cliente trouxe.', 'erro');
    await db.query(`INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES (?,NULL,'cliente',?,?,0)`, [id, b.descricao.trim(), qtd]);
  } else {
    const [[p]] = await db.query('SELECT p.valor_venda, e.saldo, p.nome_peca FROM peca p JOIN vw_saldo_estoque e USING (id_peca) WHERE id_peca = ?', [b.id_peca]);
    if (p.saldo < qtd) return voltar(res, '/os/' + id, `Só há ${p.saldo} de "${p.nome_peca}" no estoque.`, 'erro');
    await db.query(`INSERT INTO item_peca (id_os, id_peca, origem, quantidade, valor_unitario) VALUES (?,?,'oficina',?,?)`, [id, b.id_peca, qtd, p.valor_venda]);
  }
  voltar(res, '/os/' + id, 'Peça adicionada.');
}));

app.post('/os/:id/remover', rota(async (req, res) => {
  const id = req.params.id;
  if (await estaEm(id, 'aberta')) {
    const tabela = req.body.tipo === 's' ? ['item_servico', 'id_item_servico'] : ['item_peca', 'id_item_peca'];
    await db.query(`DELETE FROM ${tabela[0]} WHERE ${tabela[1]} = ? AND id_os = ?`, [req.body.item, id]);
  }
  voltar(res, '/os/' + id, 'Item removido.');
}));

app.post('/os/:id/orcamento', rota(async (req, res) => {
  const id = req.params.id;
  if (!(await estaEm(id, 'aberta'))) return res.redirect('/os/' + id);
  const [[t]] = await db.query('SELECT total_os FROM vw_total_os WHERE id_os = ?', [id]);
  await db.query(`INSERT INTO orcamento (id_os, id_funcionario, data_orcamento, valor_total, status) VALUES (?,?,NOW(),?,'pendente')`, [id, req.body.socio, t.total_os]);
  await db.query(`UPDATE ordem_servico SET status = 'aguardando_aprovacao' WHERE id_os = ?`, [id]);
  voltar(res, '/os/' + id, `Orçamento de ${reais(t.total_os)} registrado. Aguardando o cliente responder.`);
}));

app.post('/os/:id/aprovar', rota(async (req, res) => {
  const id = req.params.id;
  if (!(await estaEm(id, 'aguardando_aprovacao'))) return res.redirect('/os/' + id);
  const con = await db.getConnection();
  try {
    await con.beginTransaction();
    await con.query(`UPDATE orcamento SET status = 'aprovado', data_decisao = NOW() WHERE id_os = ?`, [id]);
    await con.query(`UPDATE ordem_servico SET status = 'em_execucao', id_mecanico = ? WHERE id_os = ?`, [req.body.mecanico, id]);
    // dá baixa no estoque das peças da oficina (o trigger confere o saldo — RN10)
    const [pecas] = await con.query(`SELECT id_peca, SUM(quantidade) AS q FROM item_peca WHERE id_os = ? AND origem = 'oficina' GROUP BY id_peca`, [id]);
    for (const p of pecas) {
      await con.query(`INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_os, id_funcionario) VALUES (?,'saida',?,NOW(),?,?)`, [p.id_peca, p.q, id, req.body.mecanico]);
    }
    await con.commit();
    voltar(res, '/os/' + id, 'Aprovado! As peças saíram do estoque e o serviço pode começar.');
  } catch (e) {
    await con.rollback();
    voltar(res, '/os/' + id, erroAmigavel(e), 'erro');
  } finally { con.release(); }
}));

app.post('/os/:id/recusar', rota(async (req, res) => {
  const id = req.params.id;
  if (!(await estaEm(id, 'aguardando_aprovacao'))) return res.redirect('/os/' + id);
  await db.query(`UPDATE orcamento SET status = 'recusado', data_decisao = NOW() WHERE id_os = ?`, [id]);
  await db.query(`UPDATE ordem_servico SET status = 'cancelada' WHERE id_os = ?`, [id]);
  voltar(res, '/os/' + id, 'OS cancelada: o cliente recusou o orçamento.');
}));

app.post('/os/:id/pronta', rota(async (req, res) => {
  await db.query(`UPDATE ordem_servico SET status = 'pronta' WHERE id_os = ? AND status = 'em_execucao'`, [req.params.id]);
  voltar(res, '/os/' + req.params.id, 'Serviço pronto! Agora avise o cliente.');
}));

app.post('/os/:id/avisado', rota(async (req, res) => {
  await db.query('UPDATE ordem_servico SET cliente_avisado = 1 WHERE id_os = ?', [req.params.id]);
  voltar(res, '/os/' + req.params.id, 'Anotado: cliente avisado.');
}));

app.post('/os/:id/entregar', rota(async (req, res) => {
  await db.query(`UPDATE ordem_servico SET status = 'entregue', cliente_avisado = 1, data_saida = NOW(),
    garantia_ate = CURDATE() + INTERVAL 90 DAY, numero_nota_fiscal = ? WHERE id_os = ? AND status = 'pronta'`, [req.body.nf?.trim() || null, req.params.id]);
  voltar(res, '/os/' + req.params.id, 'Carro entregue. A garantia da mão de obra vale por 3 meses.');
}));

app.post('/os/:id/pagamento', rota(async (req, res) => {
  const id = req.params.id, b = req.body, valor = Number(b.valor);
  const [[t]] = await db.query('SELECT saldo_devedor FROM vw_total_os WHERE id_os = ?', [id]);
  if (!(valor > 0) || valor > t.saldo_devedor + 0.001) return voltar(res, '/os/' + id, `O valor precisa ser entre R$ 0,01 e ${reais(t.saldo_devedor)}.`, 'erro');
  try {
    await db.query('INSERT INTO pagamento (id_os, data_pagamento, forma_pagamento, parcelas, valor_pago) VALUES (?,NOW(),?,?,?)', [id, b.forma, b.forma === 'credito' ? Number(b.parcelas || 1) : 1, valor]);
    voltar(res, '/os/' + id, `Pagamento de ${reais(valor)} registrado.`);
  } catch (e) { voltar(res, '/os/' + id, erroAmigavel(e), 'erro'); }
}));

// ---------------------------------------------------------------- relatórios (lidos do docs/script.sql)
function carregarConsultas() {
  const texto = fs.readFileSync(path.join(__dirname, '..', '..', 'docs', 'script.sql'), 'utf8');
  const lista = [];
  const re = /^-- ([GA]\d\d) — (.+)\n-- (?:Atende|Verifica): (.+)\n([\s\S]*?)(?=\n-- [GA]\d\d — |\n-- =+|(?![\s\S]))/gm;
  let m;
  while ((m = re.exec(texto))) lista.push({ cod: m[1], pergunta: m[2].trim(), atende: m[3].trim(), sql: m[4].trim().replace(/;\s*$/, '') });
  return lista;
}

app.get('/relatorios', (req, res) => {
  const lista = carregarConsultas();
  const bloco = (tipo) => lista.filter((c) => c.cod[0] === tipo).map((c) => `<a class="relatorio" href="/relatorios/${c.cod}"><b>${c.cod}</b> ${h(c.pergunta)}</a>`).join('');
  res.send(pagina('Relatórios', `<h1>Relatórios</h1><p>Clique numa pergunta para ver a resposta com os dados de hoje.</p>
    <h2>Gestão da oficina</h2><div class="lista-rel">${bloco('G')}</div>
    <h2>Conferência dos dados</h2><p class="dica">Se a conferência não mostrar nada, está tudo certo.</p><div class="lista-rel">${bloco('A')}</div>`));
});

app.get('/relatorios/:cod', rota(async (req, res) => {
  const c = carregarConsultas().find((x) => x.cod === req.params.cod);
  if (!c) return res.redirect('/relatorios');
  const [linhas, campos] = await db.query(c.sql);
  const cols = campos.map((f) => f.name);
  const fmt = (col, v) => (v == null ? '' : /valor|total|receita|saldo_devedor|ticket|media_|pago|recebido|orcado|cobrado/.test(col) && typeof v === 'number' ? reais(v) : /data|garantia/.test(col) ? dataBR(v) : h(v));
  res.send(pagina(c.cod, `<p><a href="/relatorios">← Relatórios</a></p><h1>${c.cod} — ${h(c.pergunta)}</h1><p class="dica">${h(c.atende)}</p>
    ${linhas.length ? `<table><tr>${cols.map((k) => `<th>${h(k.replace(/_/g, ' '))}</th>`).join('')}</tr>
      ${linhas.map((l) => `<tr>${cols.map((k) => `<td>${fmt(k, l[k])}</td>`).join('')}</tr>`).join('')}</table>`
      : `<div class="aviso ok">${c.cod[0] === 'A' ? 'Nenhum problema encontrado. ✔' : 'Nenhum resultado.'}</div>`}`));
}));

// ---------------------------------------------------------------- inicialização
(async function iniciar() {
  for (let i = 0; i < 30; i++) {
    try { await db.query('SELECT 1'); break; } catch { await new Promise((r) => setTimeout(r, 1000)); }
  }
  app.listen(PORTA, '127.0.0.1', () => {
    console.log(`Sistema da Oficina Fraga aberto em http://127.0.0.1:${PORTA}`);
    console.log('Para desligar, feche esta janela.');
    if (process.env.ABRIR_NAVEGADOR) require('child_process').exec(`start "" http://127.0.0.1:${PORTA}`);
  });
})();
