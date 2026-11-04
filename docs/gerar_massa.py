"""Gera a massa de dados fictícia do Centro Automotivo Fraga e grava no docs/script.sql.

Uso:  python docs/gerar_massa.py
O bloco entre "-- [MASSA INICIO]" e "-- [MASSA FIM]" do script.sql é substituído.
A semente é fixa: rodar de novo gera exatamente os mesmos dados.

Período simulado: setembro/2026 (1 mês). A oficina faz de 6 a 8 atendimentos por dia
útil (132 a 180 por mês); aqui saem ~150 OS. Todos os nomes, documentos, placas e
telefones são inventados.
"""
import random
from datetime import date, datetime, timedelta


def mais_3_meses(d):
    """Mesmo dia, 3 meses depois (último dia do mês quando não existe), como INTERVAL 3 MONTH no MySQL."""
    m = d.month + 3
    a, m = d.year + (m - 1) // 12, (m - 1) % 12 + 1
    import calendar
    return date(a, m, min(d.day, calendar.monthrange(a, m)[1]))
from pathlib import Path

random.seed(2026)

SCRIPT = Path(__file__).with_name("script.sql")
HOJE = datetime(2026, 10, 1, 8, 0)           # extração dos dados: manhã de 01/10/2026
INICIO = date(2026, 9, 1)

# ----------------------------------------------------------------------------
# Catálogos
# ----------------------------------------------------------------------------
# (nome, funcao, pode_editar_cadastro) — nomes fictícios; papéis iguais aos da oficina real
FUNCIONARIOS = [
    ("Paulo Henrique Fraga", "socio", 0),        # sócio: avaliação
    ("Marcos Antônio Lima", "socio", 1),         # sócio: avaliação + orçamento + cadastro
    ("Renato Carvalho Dias", "socio", 0),        # sócio: avaliação + orçamento
    ("Nicolau Ferreira Souza", "recepcionista", 1),
    ("Sérgio Batista Rocha", "mecanico", 0),
    ("Caio Mendes Pereira", "mecanico", 0),
    ("Jonas Almeida Prado", "mecanico", 0),
    ("Iago Nascimento Reis", "mecanico", 0),
    ("Leandro Moraes Pinto", "mecanico", 0),
]
SOCIOS_ORCAMENTO = [2, 3]
RECEPCAO = 4
MECANICOS = [5, 6, 7, 8, 9]

# (nome, codigo, unidade, valor_venda, custo, estoque_minimo, estoque_inicial)
PECAS = [
    ("Óleo de motor 5W30 sintético", "OL-5W30-1L", "litro", 48.00, 29.00, 40, 60),
    ("Filtro de óleo", "FO-0101", "un", 38.00, 19.50, 15, 25),
    ("Filtro de ar do motor", "FA-0202", "un", 55.00, 27.00, 8, 10),
    ("Filtro de combustível", "FC-0303", "un", 62.00, 31.00, 6, 8),
    ("Filtro de ar-condicionado (cabine)", "FCB-0404", "un", 58.00, 26.00, 6, 8),
    ("Kit correia dentada + tensor", "KCD-1500", "kit", 420.00, 260.00, 3, 4),
    ("Jogo de pastilhas de freio dianteiro", "PF-2201", "jogo", 160.00, 85.00, 5, 7),
    ("Disco de freio dianteiro", "DF-2301", "un", 190.00, 105.00, 4, 6),
    ("Amortecedor dianteiro", "AM-3101", "un", 380.00, 230.00, 4, 4),
    ("Kit embreagem", "KE-4100", "kit", 890.00, 560.00, 2, 2),
    ("Vela de ignição", "VI-5101", "un", 32.00, 15.00, 16, 24),
    ("Bateria 60Ah", "BT-60AH", "un", 520.00, 360.00, 2, 3),
    ("Fluido de freio DOT4 500ml", "FF-DOT4", "un", 45.00, 22.00, 6, 10),
    ("Aditivo de radiador 1L", "AR-1000", "litro", 35.00, 16.00, 8, 12),
    ("Bomba d'água", "BA-6101", "un", 310.00, 190.00, 2, 2),
    ("Bieleta da suspensão", "BL-3201", "un", 95.00, 48.00, 4, 6),
    ("Terminal de direção", "TD-3301", "un", 110.00, 58.00, 4, 6),
    ("Lâmpada farol H4", "LP-H4", "un", 28.00, 12.00, 10, 12),
    ("Palheta do limpador", "PL-0500", "jogo", 70.00, 34.00, 4, 6),
    ("Correia do alternador", "CA-6PK", "un", 85.00, 40.00, 3, 4),
]
P = {p[1]: i + 1 for i, p in enumerate(PECAS)}  # código → id_peca

# (nome, descrição, valor_base, [(codigo_peca, qtd)])
SERVICOS = [
    ("Troca de óleo e filtro", "Óleo do motor e filtro de óleo", 120.00, [("OL-5W30-1L", 4), ("FO-0101", 1)]),
    ("Revisão completa", "Revisão com troca de filtros, óleo e checklist de 40 itens", 350.00,
     [("OL-5W30-1L", 4), ("FO-0101", 1), ("FA-0202", 1), ("FC-0303", 1)]),
    ("Troca de correia dentada", "Substituição do kit de correia dentada e tensor", 450.00, [("KCD-1500", 1)]),
    ("Troca de pastilhas de freio", "Pastilhas do eixo dianteiro", 180.00, [("PF-2201", 1)]),
    ("Troca de discos de freio", "Discos do eixo dianteiro", 220.00, [("DF-2301", 2), ("PF-2201", 1)]),
    ("Alinhamento e balanceamento", "Alinhamento 3D e balanceamento das 4 rodas", 150.00, []),
    ("Troca de amortecedores dianteiros", "Par de amortecedores dianteiros", 300.00, [("AM-3101", 2)]),
    ("Troca de embreagem", "Kit de embreagem (platô, disco e rolamento)", 650.00, [("KE-4100", 1)]),
    ("Diagnóstico eletrônico", "Leitura de falhas com scanner", 120.00, []),
    ("Limpeza de bicos injetores", "Limpeza por ultrassom", 180.00, []),
    ("Troca de velas", "Jogo de velas de ignição", 100.00, [("VI-5101", 4)]),
    ("Troca de bateria", "Substituição e teste do sistema de carga", 60.00, [("BT-60AH", 1)]),
    ("Higienização do ar-condicionado", "Higienização e troca do filtro de cabine", 150.00, [("FCB-0404", 1)]),
    ("Troca de fluido de freio", "Sangria e troca do fluido", 120.00, [("FF-DOT4", 2)]),
    ("Troca de líquido de arrefecimento", "Drenagem e reposição do aditivo", 130.00, [("AR-1000", 3)]),
    ("Troca de bomba d'água", "Substituição da bomba d'água", 280.00, [("BA-6101", 1), ("AR-1000", 2)]),
    ("Troca de bieletas", "Par de bieletas da suspensão dianteira", 120.00, [("BL-3201", 2)]),
    ("Troca de terminais de direção", "Par de terminais + alinhamento", 140.00, [("TD-3301", 2)]),
    ("Reparo elétrico", "Hora técnica de elétrica", 150.00, [("LP-H4", 1)]),
    ("Troca de correia do alternador", "Correia poly-V do alternador", 90.00, [("CA-6PK", 1)]),
]
# peso de cada serviço no sorteio (troca de óleo e freios são os mais comuns)
PESOS_SERVICO = [22, 8, 4, 10, 4, 12, 3, 2, 7, 3, 4, 3, 4, 3, 3, 2, 3, 2, 5, 2]

PROBLEMAS = {
    0: "Troca de óleo vencida pela km", 1: "Revisão dos 40 mil km", 2: "Correia dentada no prazo de troca",
    3: "Barulho ao frear", 4: "Volante treme ao frear", 5: "Carro puxando para o lado",
    6: "Barulho na suspensão em lombadas", 7: "Embreagem patinando", 8: "Luz de injeção acesa no painel",
    9: "Motor falhando em marcha lenta", 10: "Carro falhando na partida", 11: "Carro não dá partida",
    12: "Cheiro ruim no ar-condicionado", 13: "Pedal de freio baixo", 14: "Motor esquentando",
    15: "Vazamento de água no motor", 16: "Estalo na suspensão", 17: "Folga na direção",
    18: "Farol queimado e pane elétrica", 19: "Chiado no motor ao ligar",
}

FORNECEDORES = [
    ("Auto Peças Carmo Ltda.", "12.345.678/0001-90", "(11) 2522-1000"),
    ("Distribuidora Leste Autopeças Ltda.", "23.456.789/0001-01", "(11) 2041-2200"),
    ("Itaquera Rolamentos e Peças Ltda.", "34.567.890/0001-12", "(11) 2286-3300"),
    ("Lubrificantes Zona Leste Ltda.", "45.678.901/0001-23", "(11) 2944-4400"),
    ("Freios & Cia Comércio de Peças Ltda.", "56.789.012/0001-34", "(11) 2721-5500"),
    ("Baterias Penha Comércio Ltda.", "67.890.123/0001-45", "(11) 2958-6600"),
]

NOMES = ["Ana", "Bruno", "Carla", "Daniel", "Eduarda", "Felipe", "Gabriela", "Henrique", "Isabela",
         "Jorge", "Karina", "Lucas", "Mariana", "Nelson", "Olívia", "Pedro", "Quésia", "Rafael",
         "Simone", "Thiago", "Ursula", "Vinícius", "Wagner", "Yasmin", "Zeca", "Aline", "Bento",
         "Cíntia", "Davi", "Elaine", "Fábio", "Gisele", "Hugo", "Ingrid", "Júlio", "Lívia", "Márcio",
         "Natália", "Otávio", "Patrícia", "Ricardo", "Sabrina", "Tadeu", "Vanessa", "Wellington"]
SOBRENOMES = ["Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira",
              "Lima", "Gomes", "Costa", "Ribeiro", "Martins", "Carvalho", "Rocha", "Almeida", "Nunes",
              "Mendes", "Barros", "Freitas", "Teixeira", "Moreira", "Cardoso", "Araújo", "Batista"]
RUAS = ["Av. Osvaldo Pucci", "Rua Arraial de São Bartolomeu", "Av. Jacu-Pêssego", "Rua Gregório Ramalho",
        "Rua Pedro Bueno", "Av. Itaquera", "Rua Virgínia Ferni", "Rua Dr. Luís Aires", "Av. Líder",
        "Rua Ernesto Mazzei", "Rua Antônio Thadeo", "Av. Pires do Rio"]
BAIRROS = ["Jardim Nossa Sra. do Carmo", "Itaquera", "Cidade Líder", "Parque do Carmo", "José Bonifácio",
           "Vila Carmosina", "Jardim Helena", "Guaianases", "Artur Alvim"]
MODELOS = [  # marca, modelo, motores possíveis
    ("Fiat", "Uno", ["1.0"]), ("Fiat", "Palio", ["1.0", "1.4"]), ("Fiat", "Strada", ["1.3", "1.4"]),
    ("Fiat", "Argo", ["1.0", "1.3"]), ("Fiat", "Mobi", ["1.0"]), ("Volkswagen", "Gol", ["1.0", "1.6"]),
    ("Volkswagen", "Fox", ["1.0", "1.6"]), ("Volkswagen", "Voyage", ["1.6"]), ("Volkswagen", "Polo", ["1.0 TSI"]),
    ("Volkswagen", "Saveiro", ["1.6"]), ("Chevrolet", "Onix", ["1.0", "1.4"]), ("Chevrolet", "Prisma", ["1.4"]),
    ("Chevrolet", "Celta", ["1.0"]), ("Chevrolet", "Cruze", ["1.4 T"]), ("Ford", "Ka", ["1.0", "1.5"]),
    ("Ford", "Fiesta", ["1.6"]), ("Ford", "EcoSport", ["1.6", "2.0"]), ("Hyundai", "HB20", ["1.0", "1.6"]),
    ("Renault", "Sandero", ["1.0", "1.6"]), ("Renault", "Logan", ["1.6"]), ("Toyota", "Corolla", ["2.0"]),
    ("Toyota", "Etios", ["1.5"]), ("Honda", "Civic", ["2.0"]), ("Honda", "Fit", ["1.5"]),
]


# ----------------------------------------------------------------------------
# Utilitários
# ----------------------------------------------------------------------------
def q(v):
    """Valor Python → literal SQL."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        return f"{v:.2f}"
    if isinstance(v, datetime):
        return f"'{v:%Y-%m-%d %H:%M:%S}'"
    if isinstance(v, date):
        return f"'{v:%Y-%m-%d}'"
    return "'" + str(v).replace("'", "''") + "'"


def insert(tabela, colunas, linhas, lote=50):
    out = []
    for i in range(0, len(linhas), lote):
        bloco = linhas[i:i + lote]
        valores = ",\n  ".join("(" + ", ".join(q(v) for v in l) + ")" for l in bloco)
        out.append(f"INSERT INTO {tabela} ({', '.join(colunas)}) VALUES\n  {valores};")
    return "\n".join(out)


def cpf():
    n = [random.randint(0, 9) for _ in range(9)]
    for k in (10, 11):
        s = sum(d * w for d, w in zip(n, range(k, 1, -1)))
        n.append(0 if s % 11 < 2 else 11 - s % 11)
    s = "".join(map(str, n))
    return f"{s[:3]}.{s[3:6]}.{s[6:9]}-{s[9:]}"


def cnpj():
    n = [random.randint(0, 9) for _ in range(8)] + [0, 0, 0, 1]
    for pesos in ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]):
        s = sum(d * w for d, w in zip(n, pesos))
        n.append(0 if s % 11 < 2 else 11 - s % 11)
    s = "".join(map(str, n))
    return f"{s[:2]}.{s[2:5]}.{s[5:8]}/{s[8:12]}-{s[12:]}"


def placa(usadas):
    while True:
        letras = "".join(random.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ") for _ in range(3))
        meio = random.choice("ABCDEFGHIJ0123456789")
        p = f"{letras}{random.randint(0, 9)}{meio}{random.randint(0, 99):02d}"
        if p not in usadas:
            usadas.add(p)
            return p


def dias_uteis():
    d, out = INICIO, []
    while d.month == 9:
        if d.weekday() < 6:          # segunda a sábado
            out.append(d)
        d += timedelta(days=1)
    return out


# ----------------------------------------------------------------------------
# Cadastros
# ----------------------------------------------------------------------------
funcionarios = [(n, f, f"(11) 9{random.randint(1000, 9999)}-{random.randint(1000, 9999)}", e, 1)
                for n, f, e in FUNCIONARIOS]

clientes, docs = [], set()
for i in range(110):
    if i % 15 == 14:   # algumas empresas (frota pequena)
        tipo, doc = "J", cnpj()
        nome = f"{random.choice(SOBRENOMES)} {random.choice(['Transportes', 'Entregas', 'Serviços'])} Ltda."
    else:
        tipo, doc = "F", cpf()
        nome = f"{random.choice(NOMES)} {random.choice(SOBRENOMES)} {random.choice(SOBRENOMES)}"
    if doc in docs:
        continue
    docs.add(doc)
    cad = date(2015, 1, 1) + timedelta(days=random.randint(0, 4200))
    cad = min(cad, date(2026, 9, 25))
    email = None if random.random() < 0.4 else f"cliente{i + 1}@email.exemplo"
    clientes.append((nome, tipo, doc, f"(11) 9{random.randint(1000, 9999)}-{random.randint(1000, 9999)}",
                     email, random.choice(RUAS), str(random.randint(10, 2500)), random.choice(BAIRROS),
                     "São Paulo", "SP", f"08{random.randint(200, 299)}-{random.randint(0, 999):03d}",
                     cad, 1))
# RN14: um cliente antigo ainda sem consentimento registrado (aparece na auditoria A10)
c = list(clientes[7]); c[12] = 0; clientes[7] = tuple(c)

veiculos, placas = [], set()
for id_cli in range(1, len(clientes) + 1):
    for _ in range(2 if (id_cli % 6 == 0 or clientes[id_cli - 1][1] == "J") else 1):
        marca, modelo, motores = random.choice(MODELOS)
        ano = random.randint(2008, 2025)
        km = (2026 - ano) * random.randint(9000, 16000) + random.randint(0, 5000)
        veiculos.append([id_cli, placa(placas), marca, modelo, ano, random.choice(motores), km])

servicos = [(n, d, v, 1) for n, d, v, _ in SERVICOS]
pecas = [(n, c, u, v, m, 1) for n, c, u, v, _, m, _ in PECAS]
fornecedores = [(r, c, t, f"vendas{i + 1}@fornecedor.exemplo", 1) for i, (r, c, t) in enumerate(FORNECEDORES)]

# ----------------------------------------------------------------------------
# Simulação do mês: OS, orçamentos, itens, compras e estoque
# ----------------------------------------------------------------------------
saldo = {i + 1: PECAS[i][6] for i in range(len(PECAS))}
eventos = []            # (datetime, ordem, linha de movimentacao) — inseridos em ordem cronológica
compras, itens_compra = [], []
os_rows, orc_rows, itens_serv, itens_peca, pagamentos = [], [], [], [], []

inv = datetime(2026, 8, 31, 17, 0)
for id_p in saldo:
    eventos.append((inv, 0, [id_p, "entrada", saldo[id_p], inv, None, None, RECEPCAO, "Inventário inicial (contagem física)"]))


def nova_compra(dia, itens, recebe_dias=1, conferida=1, recebida=True):
    """Registra compra; se recebida e conferida, gera as entradas no estoque."""
    id_forn = random.randint(1, len(FORNECEDORES))
    receb = dia + timedelta(days=recebe_dias) if recebida else None
    compras.append([id_forn, RECEPCAO, dia, f"NF{random.randint(100000, 999999)}" if recebida else None, receb, conferida])
    id_c = len(compras)
    for id_p, qtd in itens:
        itens_compra.append((id_c, id_p, qtd, PECAS[id_p - 1][4]))
        if recebida and conferida:
            quando = datetime.combine(receb, datetime.min.time()) + timedelta(hours=9)
            saldo[id_p] += qtd
            eventos.append((quando, 1, [id_p, "entrada", qtd, quando, id_c, None, RECEPCAO, None]))
    return id_c


def reposicao_semanal(dia):
    itens = [(id_p, PECAS[id_p - 1][5] * 2 - saldo[id_p]) for id_p in saldo
             if saldo[id_p] < PECAS[id_p - 1][5] and PECAS[id_p - 1][5] * 2 - saldo[id_p] > 0]
    if itens:
        nova_compra(dia, itens, recebe_dias=2)


numero = 25100
ultimo_momento = datetime(2026, 9, 1)
uteis = dias_uteis()
segundas = {d for d in uteis if d.weekday() == 0}
for dia in uteis:
    if dia in segundas and dia > INICIO:
        reposicao_semanal(dia - timedelta(days=2))   # pedido feito no sábado, chega na segunda
    n_os = random.choice([5, 6, 6, 6, 7]) if dia.weekday() < 5 else 3
    for _ in range(n_os):
        numero += 1
        entrada = datetime.combine(dia, datetime.min.time()) + timedelta(hours=random.randint(8, 16),
                                                                         minutes=random.choice([0, 10, 20, 30, 40, 50]))
        id_v = random.randint(1, len(veiculos))
        v = veiculos[id_v - 1]
        v[6] += random.randint(300, 2500)
        km_entrada = v[6]
        n_serv = random.choices([1, 2, 3], weights=[60, 30, 10])[0]
        escolhidos = []
        while len(escolhidos) < n_serv:
            s = random.choices(range(len(SERVICOS)), weights=PESOS_SERVICO)[0]
            if s not in escolhidos:
                escolhidos.append(s)
        if 0 in escolhidos and 1 in escolhidos:   # a revisão completa já inclui a troca de óleo
            escolhidos.remove(0)
        problema = PROBLEMAS[escolhidos[0]]
        idade = (HOJE - entrada).days
        atendente = RECEPCAO if random.random() < 0.85 else 2

        # destino da OS
        r = random.random()
        if idade >= 4:
            status = "cancelada" if r < 0.09 else "entregue"   # orçamento recusado ou desistência
        elif idade >= 2:
            status = random.choice(["entregue", "entregue", "pronta", "em_execucao"])
        elif idade >= 1:
            status = random.choice(["pronta", "em_execucao", "em_execucao", "aguardando_aprovacao"])
        else:
            status = random.choice(["em_execucao", "aguardando_aprovacao", "aberta"])

        id_os = len(os_rows) + 1
        mecanico = random.choice(MECANICOS) if status in ("em_execucao", "pronta", "entregue") else None
        previsao = (entrada + timedelta(days=random.randint(1, 3))).date()

        # itens planejados (orçamento)
        serv_itens, peca_itens = [], []
        for s in escolhidos:
            valor = round(SERVICOS[s][2] * random.choice([1, 1, 1, 0.95, 0.9]), 2)
            serv_itens.append((s + 1, valor))
            for cod, qtd in SERVICOS[s][3]:
                id_p = P[cod]
                if random.random() < 0.12 and PECAS[id_p - 1][2] != "litro":
                    peca_itens.append((None, "cliente", PECAS[id_p - 1][0] + " (trazida pelo cliente)", qtd, 0.0))
                else:
                    peca_itens.append((id_p, "oficina", None, qtd, PECAS[id_p - 1][3]))
        juntas = {}                               # a mesma peça em dois serviços vira um item só
        for id_p, origem, desc, qtd, vu in peca_itens:
            chave = (id_p, origem, desc)
            juntas[chave] = juntas.get(chave, 0) + qtd
        peca_itens = [(k[0], k[1], k[2], qtd, PECAS[k[0] - 1][3] if k[1] == "oficina" else 0.0)
                      for k, qtd in juntas.items()]
        total = round(sum(v for _, v in serv_itens) + sum(q_ * vu for _, o, _, q_, vu in peca_itens), 2)

        # orçamento (0..1): só não existe em OS aberta ou cancelada antes da avaliação
        tem_orc = status != "aberta" and not (status == "cancelada" and random.random() < 0.5)
        orc_status = None
        if tem_orc:
            data_orc = entrada + timedelta(hours=random.randint(1, 4))
            if status == "aguardando_aprovacao":
                orc_status, decisao = "pendente", None
            elif status == "cancelada":
                orc_status, decisao = "recusado", data_orc + timedelta(hours=random.randint(2, 20))
            else:
                orc_status, decisao = "aprovado", data_orc + timedelta(hours=random.randint(1, 6))
            orc_rows.append([id_os, random.choice(SOCIOS_ORCAMENTO), data_orc, total, orc_status, decisao,
                             "Cliente pediu para usar a peça própria" if any(o == "cliente" for _, o, *_ in peca_itens)
                             else None])

        executa = status in ("em_execucao", "pronta", "entregue")
        pronta = saida = garantia = nf = None
        avisado = 0
        if status in ("pronta", "entregue"):
            fim = entrada + timedelta(days=random.choice([0, 1, 1, 2, 3]), hours=random.randint(1, 5))
            fim = min(fim, HOJE - timedelta(hours=1))
            pronta = fim                                   # liberação: serviço terminado
            avisado = 1 if status == "entregue" or random.random() < 0.6 else 0
            if status == "entregue":
                saida = min(pronta + timedelta(hours=2), HOJE - timedelta(minutes=30))   # retirada pelo cliente
                garantia = mais_3_meses(saida.date())
                nf = f"NFSe-{numero}"
        os_rows.append([numero, id_v, v[0], atendente, mecanico, km_entrada, problema, entrada, previsao, pronta,
                        saida, status, avisado, garantia, nf, None])

        if executa:
            for id_s, valor in serv_itens:
                itens_serv.append([id_os, id_s, 1, valor, 0])
            # saídas em ordem crescente de horário, para o saldo bater com a ordem cronológica
            momento = max(entrada + timedelta(hours=random.randint(1, 3)), ultimo_momento + timedelta(minutes=1))
            ultimo_momento = momento
            for id_p, origem, desc, qtd, vu in peca_itens:
                itens_peca.append([id_os, id_p, origem, desc, qtd, vu])
                if origem == "oficina":
                    if saldo[id_p] < qtd:   # compra emergencial na autopeças do bairro, chega no dia
                        nova_compra(momento.date(), [(id_p, qtd + PECAS[id_p - 1][5])], recebe_dias=0)
                        eventos[-1] = (momento - timedelta(minutes=30), 1, eventos[-1][2])
                        eventos[-1][2][3] = momento - timedelta(minutes=30)
                    saldo[id_p] -= qtd
                    mec = mecanico or random.choice(MECANICOS)
                    eventos.append((momento, 2, [id_p, "saida", qtd, momento, None, id_os, mec, None]))

        # pagamentos (RN03): à vista, entrada + restante, ou parcial com saldo devedor
        if status == "entregue":
            forma = random.choices(["pix", "credito", "debito", "dinheiro"], weights=[35, 30, 20, 15])[0]
            parc = random.choice([1, 2, 3, 4, 6]) if forma == "credito" else 1
            r = random.random()
            if r < 0.12:                             # pagou só uma parte (P4)
                pagamentos.append([id_os, saida, forma, parc, round(total * random.choice([0.3, 0.5, 0.6]), 2)])
            elif r < 0.30:                           # entrada na aprovação + restante na retirada
                ent = round(total * 0.5, 2)
                pagamentos.append([id_os, entrada + timedelta(hours=6), "pix", 1, ent])
                pagamentos.append([id_os, saida, forma, parc, round(total - ent, 2)])
            else:
                pagamentos.append([id_os, saida, forma, parc, total])
        elif status in ("pronta", "em_execucao") and random.random() < 0.3:
            pagamentos.append([id_os, entrada + timedelta(hours=6), "pix", 1, round(total * 0.5, 2)])

# RN05 — retrabalho de garantia: o cliente volta, a MESMA OS recebe o serviço sem custo
entregues = [i for i, o in enumerate(os_rows) if o[11] == "entregue" and o[10] < datetime(2026, 9, 20)]
for idx in random.sample(entregues, 6):
    id_os = idx + 1
    id_s = next(it[1] for it in itens_serv if it[0] == id_os)
    volta = os_rows[idx][10] + timedelta(days=random.randint(3, 9))
    itens_serv.append([id_os, id_s, 1, 0.0, 1])
    os_rows[idx][15] = (f"Retorno em garantia em {volta:%d/%m/%Y}: refeito o serviço "
                        f"'{SERVICOS[id_s - 1][0]}' sem custo; data de entrada mantida (RN05).")

# Situações que as auditorias devem encontrar (registros reais de dia a dia)
# A02: uma OS foi para execução antes do cliente aprovar o orçamento
alvo = next(i for i, o in enumerate(os_rows) if o[11] == "em_execucao")
for orc in orc_rows:
    if orc[0] == alvo + 1:
        orc[4], orc[5] = "pendente", None
# A08: compra recebida, mas ainda não conferida — por isso sem entrada no estoque
nova_compra(date(2026, 9, 29), [(P["PF-2201"], 4), (P["FO-0101"], 10)], recebe_dias=1, conferida=0)
# compra feita e ainda não entregue pelo fornecedor
nova_compra(date(2026, 9, 30), [(P["KE-4100"], 2)], recebida=False, conferida=0)

# ----------------------------------------------------------------------------
# Saída SQL
# ----------------------------------------------------------------------------
eventos.sort(key=lambda e: (e[0], e[1]))
movs = [e[2] for e in eventos]

blocos = [
    "-- Volumes (setembro/2026): justificativa no README, seção 4",
    insert("funcionario", ["nome", "funcao", "telefone", "pode_editar_cadastro", "ativo"], funcionarios),
    insert("cliente", ["nome", "tipo_pessoa", "cpf_cnpj", "telefone", "email", "logradouro", "numero", "bairro",
                       "cidade", "uf", "cep", "data_cadastro", "consentimento_lgpd"], clientes),
    insert("veiculo", ["id_cliente", "placa", "marca", "modelo", "ano", "motor", "km_atual"], veiculos),
    insert("servico", ["nome_servico", "descricao", "valor_base", "ativo"], servicos),
    insert("peca", ["nome_peca", "codigo_fabricante", "unidade", "valor_venda", "estoque_minimo", "ativo"], pecas),
    insert("fornecedor", ["razao_social", "cnpj", "telefone", "email", "ativo"], fornecedores),
    insert("ordem_servico", ["numero_os", "id_veiculo", "id_cliente", "id_atendente", "id_mecanico", "km_entrada",
                             "problema_relatado", "data_entrada", "data_previsao", "data_pronta", "data_saida", "status",
                             "cliente_avisado", "garantia_ate", "numero_nota_fiscal", "observacoes"], os_rows),
    insert("orcamento", ["id_os", "id_funcionario", "data_orcamento", "valor_total", "status", "data_decisao",
                         "observacoes"], orc_rows),
    insert("item_servico", ["id_os", "id_servico", "quantidade", "valor_cobrado", "retrabalho_garantia"], itens_serv),
    insert("item_peca", ["id_os", "id_peca", "origem", "descricao_peca_cliente", "quantidade", "valor_unitario"],
           itens_peca),
    insert("compra", ["id_fornecedor", "id_funcionario", "data_compra", "numero_nota_fiscal", "data_recebimento",
                      "conferida"], compras),
    insert("item_compra", ["id_compra", "id_peca", "quantidade", "custo_unitario"], itens_compra),
    "-- movimentações em ordem cronológica (o trigger confere o saldo a cada saída)",
    insert("movimentacao_estoque", ["id_peca", "tipo", "quantidade", "data_movimentacao", "id_compra", "id_os",
                                    "id_funcionario", "motivo"], movs),
    insert("pagamento", ["id_os", "data_pagamento", "forma_pagamento", "parcelas", "valor_pago"], pagamentos),
]
massa = "\n\n".join(blocos)

texto = SCRIPT.read_text(encoding="utf-8")
ini, fim = "-- [MASSA INICIO]", "-- [MASSA FIM]"
a, b = texto.index(ini) + len(ini), texto.index(fim)
SCRIPT.write_text(texto[:a] + "\n" + massa + "\n" + texto[b:], encoding="utf-8", newline="\n")

contagem = {"funcionario": len(funcionarios), "cliente": len(clientes), "veiculo": len(veiculos),
            "servico": len(servicos), "peca": len(pecas), "fornecedor": len(fornecedores),
            "ordem_servico": len(os_rows), "orcamento": len(orc_rows), "item_servico": len(itens_serv),
            "item_peca": len(itens_peca), "compra": len(compras), "item_compra": len(itens_compra),
            "movimentacao_estoque": len(movs), "pagamento": len(pagamentos)}
for t, n in contagem.items():
    print(f"{t:22s} {n:4d}")
