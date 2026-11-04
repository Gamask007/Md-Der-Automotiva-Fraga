# Dicionário de Dados — Centro Automotivo Fraga

> Turma GTI: dicionário em arquivo Markdown separado do README.

| Item | Valor |
| :--- | :--- |
| Banco | `fraga_oficina` |
| Versão do dicionário | 2.1 (Entrega 2) — 2026-11-04 |
| Fonte da verdade | [`docs/script.sql`](script.sql) — se o dicionário e o script divergirem, vale o script |
| Tabelas | 14 tabelas + 2 views (`vw_saldo_estoque`, `vw_total_os`) + 1 trigger (`tg_mov_saldo_nao_negativo`) |

## 1. Modelo conceitual

### 1.1 Entidades

| Entidade | Tabela | Definição |
| :--- | :--- | :--- |
| CLIENTE | `cliente` | Pessoa física ou jurídica atendida pela oficina. |
| VEICULO | `veiculo` | Carro atendido, identificado pela placa; pertence a um cliente por vez. |
| FUNCIONARIO | `funcionario` | Sócio, recepcionista ou mecânico; registra quem faz cada etapa. |
| ORDEM_SERVICO | `ordem_servico` | Atendimento de um veículo da entrada à entrega (entidade central). |
| ORCAMENTO | `orcamento` | Valor proposto ao cliente para uma OS e a decisão dele. |
| SERVICO | `servico` | Catálogo de serviços com preço de referência. |
| ITEM_SERVICO | `item_servico` | Associativa OS × SERVICO: serviço executado e valor cobrado. |
| PECA | `peca` | Catálogo de peças que a oficina compra e revende. |
| ITEM_PECA | `item_peca` | Peça usada numa OS, da oficina ou trazida pelo cliente. |
| FORNECEDOR | `fornecedor` | Autopeças de quem a oficina compra. |
| COMPRA | `compra` | Pedido de peças a um fornecedor, com recebimento e conferência. |
| ITEM_COMPRA | `item_compra` | Associativa COMPRA × PECA: quantidade e custo de cada peça. |
| MOVIMENTACAO_ESTOQUE | `movimentacao_estoque` | Cada entrada ou saída de peça; o saldo é a soma delas. |
| PAGAMENTO | `pagamento` | Cada valor recebido por uma OS (à vista, entrada ou parcial). |

### 1.2 Relacionamentos e cardinalidades

| Entidade | Relaciona-se com | Cardinalidade | Explicação |
| :--- | :--- | :--- | :--- |
| CLIENTE | VEICULO | 1 : 0..N | Um cliente pode ter vários veículos (ou nenhum, se o carro foi vendido); cada veículo tem um único dono atual. Na troca de dono, muda o `id_cliente` do veículo (RN07). |
| VEICULO | ORDEM_SERVICO | 1 : 0..N | Cada OS é de um veículo; o veículo acumula o histórico de OS. |
| FUNCIONARIO (atendente) | ORDEM_SERVICO | 1 : 0..N | Toda OS é aberta por um funcionário autorizado (RN06). |
| FUNCIONARIO (mecânico) | ORDEM_SERVICO | 0..1 : 0..N | O mecânico só é definido quando o serviço começa; um mecânico atende várias OS. |
| ORDEM_SERVICO | ORCAMENTO | 1 : 0..1 | No máximo um orçamento por OS (`UNIQUE` em `orcamento.id_os`). OS ainda aberta, ou cancelada antes da avaliação, não tem orçamento. |
| FUNCIONARIO | ORCAMENTO | 1 : 0..N | Cada orçamento é feito por um sócio (RN15). |
| ORDEM_SERVICO | SERVICO (via ITEM_SERVICO) | N : N | Uma OS tem vários serviços; um serviço do catálogo aparece em várias OS. A associativa guarda quantidade, valor cobrado e se é retrabalho. |
| ORDEM_SERVICO | ITEM_PECA | 1 : 0..N | Peças usadas na OS. |
| PECA | ITEM_PECA | 0..1 : 0..N | Peça da oficina aponta para o catálogo; peça trazida pelo cliente não tem `id_peca` e só tem descrição (RN04). |
| ORDEM_SERVICO | PAGAMENTO | 1 : 0..N | Vários pagamentos por OS: entrada, restante, parcial (RN03). |
| FORNECEDOR | COMPRA | 1 : 0..N | Toda compra é de um fornecedor cadastrado (RN11). |
| FUNCIONARIO | COMPRA | 1 : 0..N | Quem registrou a compra. |
| COMPRA | PECA (via ITEM_COMPRA) | N : N | Uma compra tem 1..N peças; uma peça aparece em várias compras. A associativa guarda quantidade e custo. |
| PECA | MOVIMENTACAO_ESTOQUE | 1 : 0..N | Cada entrada ou saída é de uma peça; o saldo é a soma das movimentações. |
| COMPRA | MOVIMENTACAO_ESTOQUE | 0..1 : 0..N | Entradas vindas de compra conferida. |
| ORDEM_SERVICO | MOVIMENTACAO_ESTOQUE | 0..1 : 0..N | Saídas de peças para uma OS. |
| FUNCIONARIO | MOVIMENTACAO_ESTOQUE | 1 : 0..N | Quem lançou a movimentação (rastreabilidade). |

## 2. Fluxo de dados

1. **Atendimento.** O cliente chega ao balcão. A recepção busca pela placa (`veiculo.placa`). Se não houver cadastro, cria `cliente` (com `consentimento_lgpd`) e `veiculo`. Depois abre a `ordem_servico` com `km_entrada`, `problema_relatado` e `data_entrada`. Status: `aberta`.
2. **Avaliação e orçamento.** Um sócio avalia o carro e registra o `orcamento` com `valor_total`. Status: `aguardando_aprovacao`.
3. **Aprovação.** O cliente aprova (`orcamento.status = aprovado`, `data_decisao`) e a OS vai para `em_execucao`, com `id_mecanico`. Se o cliente recusar, a OS fica `cancelada`.
4. **Execução.** São lançados `item_servico` e `item_peca`. Cada peça da oficina gera uma `movimentacao_estoque` do tipo saída. O trigger bloqueia a saída se não houver saldo (RN10). Peça trazida pelo cliente não mexe no estoque.
5. **Liberação.** A OS fica `pronta`, a recepção avisa o cliente (`cliente_avisado = 1`) e o cliente paga (`pagamento`, uma ou várias linhas). Na retirada, a OS fica `entregue`, com `data_saida`, `garantia_ate` (+3 meses) e `numero_nota_fiscal`.
6. **Garantia.** Se o cliente volta dentro da garantia, a mesma OS recebe um `item_servico` com `retrabalho_garantia = 1` e valor 0, e uma observação (RN05).
7. **Compras.** Quando a peça fica abaixo do `estoque_minimo` (consulta G01), registra-se a `compra` e seus `item_compra`. No recebimento, a compra é conferida (`conferida = 1`) e cada item gera uma `movimentacao_estoque` do tipo entrada.
8. **Gestão.** As consultas G01–G12 e as views leem esses dados para os relatórios. As consultas A01–A10 conferem as regras.

## 3. Convenções

| Convenção | Regra adotada |
| :--- | :--- |
| SGBD | MySQL 8 (script testado no MySQL 8.4.13) |
| Conjunto de caracteres / collation | `utf8mb4` / `utf8mb4_0900_ai_ci` (aceita acentos; buscas ignoram maiúsculas e acentos) |
| Nomes de tabelas e colunas | minúsculas, sem acento, `snake_case`, no singular (`cliente`, `ordem_servico`) |
| Chave primária | `id_<tabela>` (`id_cliente`), `INT UNSIGNED AUTO_INCREMENT`; exceção: `item_compra` tem chave composta (`id_compra`, `id_peca`) |
| Chave estrangeira | mesmo nome da PK referenciada (`id_cliente` em `veiculo`); quando a mesma tabela é referenciada duas vezes, o nome indica o papel (`id_atendente`, `id_mecanico` → `funcionario`) |
| Prefixos de colunas | `id_` identificadores · `data_` datas (`data_entrada`) · `valor_` valores em R$ (`valor_pago`) · `numero_` números de documento (`numero_os`, `numero_nota_fiscal`) · `nome` / `nome_<coisa>` nomes |
| Nomes de restrições | `pk_` chave primária · `fk_` chave estrangeira · `uq_` unicidade · `ck_` CHECK · `ix_` índice |
| Valores monetários | `DECIMAL(10,2)`, em reais |
| Sim/não | `TINYINT(1)` com `CHECK (... IN (0,1))` — 1 = sim |
| Domínios fechados | `ENUM` (ex.: `status`, `forma_pagamento`, `funcao`) |
| Notação da expressão formal | `=` é composto de · `+` e · `@` identificador · `( )` opcional · `{ }` repetição · `[ a \| b ]` escolha |
| Valores derivados | não são guardados em coluna (3FN); são calculados nas views (`saldo` do estoque, total e saldo devedor da OS) |

## 4. Dicionário por entidade

Em cada tabela: **definição**, **expressão formal**, **leitura** e, por coluna, tipo físico, obrigatoriedade (NOT NULL), unicidade (UNIQUE), valores permitidos (CHECK/ENUM), valor padrão (DEFAULT) e o significado. No fim de cada tabela, os **índices**.

### 4.1 `cliente`

- **Expressão formal:** `CLIENTE = @id_cliente + nome + tipo_pessoa + cpf_cnpj + telefone + (email) + endereco + data_cadastro + consentimento_lgpd`, com `endereco = logradouro + numero + bairro + cidade + uf + cep`
- **Leitura:** um cliente é a pessoa física ou jurídica atendida pela oficina. É identificado por um código e tem nome, documento único, telefone, e-mail opcional, endereço, data de cadastro e o registro do consentimento LGPD.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_cliente | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador do cliente |
| nome | VARCHAR(100) | sim | não | — | — | — | Nome completo ou razão social |
| tipo_pessoa | ENUM('F','J') | sim | não | — | valores do ENUM | 'F' | Física ou jurídica |
| cpf_cnpj | VARCHAR(18) | sim | sim | — | CHECK: 14 caracteres se F (000.000.000-00), 18 se J | — | Documento; uma das buscas do balcão (RN08) |
| telefone | VARCHAR(15) | sim | não | — | — | — | Contato para avisar que o carro está pronto |
| email | VARCHAR(100) | não | não | — | — | — | E-mail, se o cliente informar |
| logradouro | VARCHAR(100) | sim | não | — | — | — | Rua/avenida (1FN: endereço decomposto) |
| numero | VARCHAR(10) | sim | não | — | — | — | Número do endereço |
| bairro | VARCHAR(60) | sim | não | — | — | — | Bairro |
| cidade | VARCHAR(60) | sim | não | — | — | 'São Paulo' | Cidade |
| uf | CHAR(2) | sim | não | — | — | 'SP' | Estado |
| cep | CHAR(9) | sim | não | — | CHECK formato 00000-000 | — | CEP |
| data_cadastro | DATE | sim | não | — | — | — | Data do primeiro cadastro |
| consentimento_lgpd | TINYINT(1) | sim | não | — | CHECK 0/1 | 0 | 1 = cliente autorizou guardar os dados (RN14) |

**Índices:** PK (id_cliente) · UNIQUE (cpf_cnpj) · `ix_cliente_nome` (nome).

### 4.2 `veiculo`

- **Expressão formal:** `VEICULO = @id_veiculo + id_cliente + placa + marca + modelo + ano + (motor) + km_atual`
- **Leitura:** um veículo é identificado pela placa e pertence a um único cliente por vez.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_veiculo | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador do veículo |
| id_cliente | INT UNSIGNED | sim | não | FK → cliente (ON DELETE RESTRICT) | — | — | Dono atual (RN07) |
| placa | CHAR(7) | sim | sim | — | CHECK padrão antigo ou Mercosul (AAA0A00) | — | Busca mais usada no balcão (RN08) |
| marca | VARCHAR(30) | sim | não | — | — | — | Montadora |
| modelo | VARCHAR(40) | sim | não | — | — | — | Modelo |
| ano | SMALLINT UNSIGNED | sim | não | — | CHECK 1950–2100 | — | Ano de fabricação |
| motor | VARCHAR(10) | não | não | — | — | — | Motorização (1.0, 1.6, 2.0…) |
| km_atual | INT UNSIGNED | sim | não | — | — | 0 | Última quilometragem registrada |

**Índices:** PK (id_veiculo) · UNIQUE (placa) · índices automáticos das FKs: `id_cliente`.

### 4.3 `funcionario`

- **Expressão formal:** `FUNCIONARIO = @id_funcionario + nome + funcao + (telefone) + pode_editar_cadastro + ativo`
- **Leitura:** um funcionário é sócio, recepcionista ou mecânico; só alguns têm permissão para cadastrar e alterar dados.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_funcionario | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| nome | VARCHAR(80) | sim | não | — | — | — | Nome |
| funcao | ENUM('socio','recepcionista','mecanico') | sim | não | — | valores do ENUM | — | Papel na oficina (RN15, RN16) |
| telefone | VARCHAR(15) | não | não | — | — | — | Contato |
| pode_editar_cadastro | TINYINT(1) | sim | não | — | CHECK 0/1 | 0 | 1 = pode cadastrar e alterar dados (RN06) |
| ativo | TINYINT(1) | sim | não | — | CHECK 0/1 | 1 | 0 = desligado (mantém o histórico) |

**Índices:** PK (id_funcionario).

### 4.4 `ordem_servico`

- **Expressão formal:** `ORDEM_SERVICO = @id_os + numero_os + id_veiculo + id_atendente + (id_mecanico) + km_entrada + problema_relatado + data_entrada + (data_previsao) + (data_saida) + status + cliente_avisado + (garantia_ate) + (numero_nota_fiscal) + (observacoes)`
- **Leitura:** uma OS registra o atendimento de um veículo, da entrada até a entrega, com quem atendeu, quem executou, as datas, o status, a garantia e a nota fiscal.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_os | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador interno |
| numero_os | INT UNSIGNED | sim | sim | — | — | — | Número impresso para o cliente (RN01) |
| id_veiculo | INT UNSIGNED | sim | não | FK → veiculo (ON DELETE RESTRICT) | — | — | Veículo atendido |
| id_atendente | INT UNSIGNED | sim | não | FK → funcionario (ON DELETE RESTRICT) | — | — | Quem abriu a OS (RN06) |
| id_mecanico | INT UNSIGNED | não | não | FK → funcionario (ON DELETE RESTRICT) | — | — | Mecânico responsável (definido na execução) |
| km_entrada | INT UNSIGNED | sim | não | — | — | — | Km informada na entrada |
| problema_relatado | VARCHAR(255) | sim | não | — | — | — | Queixa do cliente |
| data_entrada | DATETIME | sim | não | — | — | — | Entrada; não muda em retrabalho (RN05) |
| data_previsao | DATE | não | não | — | — | — | Previsão de liberação informada ao cliente |
| data_saida | DATETIME | não | não | — | CHECK ≥ data_entrada; obrigatória se entregue | — | Retirada do veículo |
| status | ENUM('aberta','aguardando_aprovacao','em_execucao','pronta','entregue','cancelada') | sim | não | — | valores do ENUM | 'aberta' | Etapa da OS (substitui o antigo `pronto`) |
| cliente_avisado | TINYINT(1) | sim | não | — | CHECK 0/1 | 0 | 1 = cliente avisado de que está pronto |
| garantia_ate | DATE | não | não | — | — | — | data_saida + 3 meses de garantia da mão de obra (RN04) |
| numero_nota_fiscal | VARCHAR(20) | não | não | — | — | — | NFS-e emitida em toda entrega (RN13) |
| observacoes | TEXT | não | não | — | — | — | Anotações, incluindo retorno em garantia (RN05) |

**Índices:** PK (id_os) · UNIQUE (numero_os) · `ix_os_data_entrada` (data_entrada) · `ix_os_status` (status) · índices automáticos das FKs: `id_veiculo`, `id_atendente`, `id_mecanico`.

### 4.5 `orcamento`

- **Expressão formal:** `ORCAMENTO = @id_orcamento + id_os + id_funcionario + data_orcamento + valor_total + status + (data_decisao) + (observacoes)`
- **Leitura:** um orçamento é feito por um sócio para uma OS e fica pendente até o cliente aprovar ou recusar.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_orcamento | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| id_os | INT UNSIGNED | sim | sim | FK → ordem_servico (ON DELETE CASCADE) | — | — | Garante o 1 : 0..1 com a OS |
| id_funcionario | INT UNSIGNED | sim | não | FK → funcionario (ON DELETE RESTRICT) | — | — | Sócio que orçou (RN15) |
| data_orcamento | DATETIME | sim | não | — | — | — | Quando foi feito |
| valor_total | DECIMAL(10,2) | sim | não | — | CHECK ≥ 0 | — | Valor travado na OS (RN02) |
| status | ENUM('pendente','aprovado','recusado') | sim | não | — | valores do ENUM | 'pendente' | Decisão do cliente |
| data_decisao | DATETIME | condicional | não | — | CHECK: nula só se pendente | — | Quando o cliente decidiu |
| observacoes | VARCHAR(255) | não | não | — | — | — | Ex.: cliente vai trazer a peça |

**Índices:** PK (id_orcamento) · UNIQUE (id_os) · índices automáticos das FKs: `id_os`, `id_funcionario`.

### 4.6 `servico`

- **Expressão formal:** `SERVICO = @id_servico + nome_servico + (descricao) + valor_base + ativo`
- **Leitura:** catálogo dos serviços oferecidos, com preço de referência.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_servico | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| nome_servico | VARCHAR(80) | sim | sim | — | — | — | Nome no catálogo |
| descricao | VARCHAR(255) | não | não | — | — | — | Detalhe do serviço |
| valor_base | DECIMAL(10,2) | sim | não | — | CHECK > 0 | — | Preço de referência (RN09) |
| ativo | TINYINT(1) | sim | não | — | — | 1 | 0 = fora do catálogo |

**Índices:** PK (id_servico) · UNIQUE (nome_servico).

### 4.7 `item_servico`

- **Expressão formal:** `ITEM_SERVICO = @id_item_servico + id_os + id_servico + quantidade + valor_cobrado + retrabalho_garantia`
- **Leitura:** cada serviço executado em uma OS, com o valor realmente cobrado.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_item_servico | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador (permite repetir o serviço na mesma OS em retrabalho) |
| id_os | INT UNSIGNED | sim | não | FK → ordem_servico (ON DELETE CASCADE) | — | — | OS |
| id_servico | INT UNSIGNED | sim | não | FK → servico (ON DELETE RESTRICT) | — | — | Serviço do catálogo |
| quantidade | TINYINT UNSIGNED | sim | não | — | CHECK > 0 | 1 | Quantidade |
| valor_cobrado | DECIMAL(10,2) | sim | não | — | CHECK ≥ 0 | — | Preço praticado (pode ter desconto) |
| retrabalho_garantia | TINYINT(1) | sim | não | — | CHECK: se 1, valor = 0 | 0 | Serviço refeito em garantia (RN05) |

**Índices:** PK (id_item_servico) · índices automáticos das FKs: `id_os`, `id_servico`.

### 4.8 `peca`

- **Expressão formal:** `PECA = @id_peca + nome_peca + (codigo_fabricante) + unidade + valor_venda + estoque_minimo + ativo`
- **Leitura:** catálogo das peças que a oficina compra e revende. O saldo não fica aqui: é calculado pelas movimentações.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_peca | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| nome_peca | VARCHAR(80) | sim | não | — | — | — | Nome |
| codigo_fabricante | VARCHAR(30) | não | sim | — | — | — | Código da peça |
| unidade | ENUM('un','litro','jogo','kit') | sim | não | — | valores do ENUM | 'un' | Unidade de estoque |
| valor_venda | DECIMAL(10,2) | sim | não | — | CHECK ≥ 0 | — | Preço cobrado do cliente |
| estoque_minimo | INT UNSIGNED | sim | não | — | — | 0 | Abaixo disso, comprar (RN12) |
| ativo | TINYINT(1) | sim | não | — | — | 1 | 0 = não trabalha mais com a peça |

**Índices:** PK (id_peca) · UNIQUE (codigo_fabricante).

### 4.9 `item_peca`

- **Expressão formal:** `ITEM_PECA = @id_item_peca + id_os + [ id_peca | descricao_peca_cliente ] + origem + quantidade + valor_unitario`
- **Leitura:** cada peça usada em uma OS, da oficina (do catálogo) ou trazida pelo cliente (só descrição, sem valor e sem garantia).

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_item_peca | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| id_os | INT UNSIGNED | sim | não | FK → ordem_servico (ON DELETE CASCADE) | — | — | OS |
| id_peca | INT UNSIGNED | condicional | não | FK → peca (ON DELETE RESTRICT) | CHECK: obrigatório se origem = oficina, nulo se cliente | — | Peça do catálogo |
| origem | ENUM('oficina','cliente') | sim | não | — | valores do ENUM | 'oficina' | Quem forneceu a peça (P2, RN04) |
| descricao_peca_cliente | VARCHAR(100) | condicional | não | — | CHECK: obrigatória se origem = cliente | — | Descrição da peça trazida |
| quantidade | INT UNSIGNED | sim | não | — | CHECK > 0 | — | Quantidade |
| valor_unitario | DECIMAL(10,2) | sim | não | — | CHECK = 0 se origem = cliente | 0 | Preço praticado |

**Índices:** PK (id_item_peca) · índices automáticos das FKs: `id_os`, `id_peca`.

### 4.10 `fornecedor`

- **Expressão formal:** `FORNECEDOR = @id_fornecedor + razao_social + cnpj + telefone + (email) + ativo`
- **Leitura:** autopeças e distribuidores de quem a oficina compra.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_fornecedor | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| razao_social | VARCHAR(100) | sim | não | — | — | — | Nome da empresa |
| cnpj | CHAR(18) | sim | sim | — | — | — | CNPJ formatado |
| telefone | VARCHAR(15) | sim | não | — | — | — | Contato de vendas |
| email | VARCHAR(100) | não | não | — | — | — | E-mail |
| ativo | TINYINT(1) | sim | não | — | — | 1 | Fornecedor em uso (RN11) |

**Índices:** PK (id_fornecedor) · UNIQUE (cnpj).

### 4.11 `compra`

- **Expressão formal:** `COMPRA = @id_compra + id_fornecedor + id_funcionario + data_compra + (numero_nota_fiscal) + (data_recebimento) + conferida`
- **Leitura:** pedido de peças a um fornecedor, com o recebimento e a conferência.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_compra | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| id_fornecedor | INT UNSIGNED | sim | não | FK → fornecedor (ON DELETE RESTRICT) | — | — | Fornecedor (RN11) |
| id_funcionario | INT UNSIGNED | sim | não | FK → funcionario (ON DELETE RESTRICT) | — | — | Quem comprou |
| data_compra | DATE | sim | não | — | — | — | Data do pedido |
| numero_nota_fiscal | VARCHAR(20) | não | não | — | — | — | NF do fornecedor |
| data_recebimento | DATE | não | não | — | CHECK ≥ data_compra | — | Quando chegou |
| conferida | TINYINT(1) | sim | não | — | CHECK: só 1 se recebida | 0 | Conferência feita (libera a entrada no estoque) |

**Índices:** PK (id_compra) · índices automáticos das FKs: `id_fornecedor`, `id_funcionario`.

### 4.12 `item_compra`

- **Expressão formal:** `ITEM_COMPRA = @(id_compra + id_peca) + quantidade + custo_unitario`
- **Leitura:** cada peça de uma compra, com quantidade e custo. A chave é composta: a mesma peça não se repete na mesma compra.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_compra | INT UNSIGNED | sim | não | PK · FK → compra (ON DELETE CASCADE) | — | — | Compra |
| id_peca | INT UNSIGNED | sim | não | PK · FK → peca (ON DELETE RESTRICT) | — | — | Peça |
| quantidade | INT UNSIGNED | sim | não | — | CHECK > 0 | — | Quantidade comprada |
| custo_unitario | DECIMAL(10,2) | sim | não | — | CHECK ≥ 0 | — | Custo pago ao fornecedor |

**Índices:** PK (id_compra, id_peca) · índices automáticos das FKs: `id_compra`, `id_peca`.

### 4.13 `movimentacao_estoque`

- **Expressão formal:** `MOVIMENTACAO_ESTOQUE = @id_movimentacao + id_peca + tipo + quantidade + data_movimentacao + [ id_compra | id_os | motivo ] + id_funcionario`
- **Leitura:** cada entrada ou saída de uma peça. A entrada vem de uma compra ou de um ajuste com motivo; a saída vai para uma OS ou é um ajuste com motivo.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_movimentacao | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| id_peca | INT UNSIGNED | sim | não | FK → peca (ON DELETE RESTRICT) | — | — | Peça |
| tipo | ENUM('entrada','saida') | sim | não | — | valores do ENUM; trigger: saída ≤ saldo (RN10) | — | Sentido |
| quantidade | INT UNSIGNED | sim | não | — | CHECK > 0 | — | Quantidade movimentada |
| data_movimentacao | DATETIME | sim | não | — | — | — | Quando |
| id_compra | INT UNSIGNED | condicional | não | FK → compra (ON DELETE RESTRICT) | CHECK: só em entrada | — | Compra que originou a entrada (RN11) |
| id_os | INT UNSIGNED | condicional | não | FK → ordem_servico (ON DELETE RESTRICT) | CHECK: só em saída | — | OS que consumiu a peça |
| id_funcionario | INT UNSIGNED | sim | não | FK → funcionario (ON DELETE RESTRICT) | — | — | Quem lançou |
| motivo | VARCHAR(100) | condicional | não | — | obrigatório se não houver compra/OS | — | Ajuste (ex.: inventário inicial) |

**Índices:** PK (id_movimentacao) · `ix_mov_peca_data` (id_peca,data_movimentacao) · índices automáticos das FKs: `id_peca`, `id_compra`, `id_os`, `id_funcionario`.

### 4.14 `pagamento`

- **Expressão formal:** `PAGAMENTO = @id_pagamento + id_os + data_pagamento + forma_pagamento + parcelas + valor_pago`
- **Leitura:** cada valor recebido por uma OS; uma OS pode ter vários (entrada, restante, parcial).


O **saldo** que existia no dicionário da Entrega 1 saiu da tabela, porque é derivado (total da OS menos os pagamentos). Agora ele é calculado em `vw_total_os.saldo_devedor`.

| Coluna | Tipo físico | Obrigatório | Único | Chave | Valores permitidos (CHECK) | Padrão (DEFAULT) | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| id_pagamento | INT UNSIGNED | sim | sim | PK | — | AUTO_INCREMENT | Identificador |
| id_os | INT UNSIGNED | sim | não | FK → ordem_servico (ON DELETE RESTRICT) | — | — | OS paga |
| data_pagamento | DATETIME | sim | não | — | — | — | Quando |
| forma_pagamento | ENUM('dinheiro','pix','debito','credito') | sim | não | — | valores do ENUM | — | Forma (RN03) |
| parcelas | TINYINT UNSIGNED | sim | não | — | CHECK 1–12 e só >1 no crédito | 1 | Parcelamento |
| valor_pago | DECIMAL(10,2) | sim | não | — | CHECK > 0 | — | Valor recebido |

**Índices:** PK (id_pagamento) · índices automáticos das FKs: `id_os`.

### 4.15 Views e trigger

| Objeto | O que entrega | Regra |
| :--- | :--- | :--- |
| `vw_saldo_estoque` | `saldo` = entradas − saídas, por peça, ao lado do `estoque_minimo` | RN10, RN12 |
| `vw_total_os` | `total_servicos`, `total_pecas` (só da oficina), `total_os`, `total_pago`, `saldo_devedor` | RN02, RN03 |
| `tg_mov_saldo_nao_negativo` | Antes de inserir uma saída, confere o saldo e bloqueia com erro se não houver peça | RN10 |

## 5. Log de acesso

O que fica registrado hoje no próprio banco:

- quem abriu cada OS (`ordem_servico.id_atendente`) e quem a executou (`id_mecanico`);
- quem fez cada orçamento (`orcamento.id_funcionario`), quem registrou cada compra (`compra.id_funcionario`) e quem lançou cada movimentação de estoque (`movimentacao_estoque.id_funcionario`), todos com data e hora.

Para registrar também as **consultas** e as **alterações** de dados pessoais, propõe-se ativar no servidor o log de auditoria do MySQL (ou uma tabela de log alimentada por triggers), guardando usuário, data/hora, tabela e operação. Isso fica como **proposta de evolução**, fora do script da Entrega 2: o registro de quem fez cada operação já está nas colunas citadas acima.

| Versão | Data | Alteração | Autor |
| :--- | :--- | :--- | :--- |
| 1.0 | 2026-09-24 | Dicionário preliminar no README (Entrega 1) | Grupo |
| 2.0 | 2026-10-28 | Dicionário físico completo, separado do README (Entrega 2) | Grupo 1, com apoio de IA (ver README, seção 6) |
| 2.1 | 2026-11-04 | Seções reordenadas (modelo conceitual, fluxo, convenções, entidades); lista de entidades; colunas separadas de unicidade, CHECK e DEFAULT; índices por tabela | Grupo 1, com apoio de IA (ver README, seção 6) |

## 6. Acesso por operação e LGPD

| Tabela | Recepção | Sócio com permissão | Sócio | Mecânico |
| :--- | :--- | :--- | :--- | :--- |
| cliente, veiculo | C R U | C R U | R | — |
| ordem_servico | C R U | C R U | R U (avaliação) | R U (status, execução) |
| orcamento | R | C R U | C R U | R |
| item_servico, item_peca | R | C R U | C R U | C R |
| pagamento | C R | C R U | R | — |
| fornecedor, compra, item_compra | R | C R U | C R U | — |
| movimentacao_estoque | C R | C R U | C R | C R (saída para OS) |
| servico, peca | R | C R U | R | R |
| funcionario | — | C R U | R | — |

C = inserir · R = consultar · U = alterar. Ninguém apaga cadastros: OS e clientes ficam no histórico (`ativo = 0` ou status `cancelada`).

A matriz segue a regra da oficina de que só a recepção e o sócio autorizado cadastram e alteram dados (RN06), levantada na entrevista. O detalhamento por operação é proposta do grupo. O bloco comentado no fim da seção 3 do `script.sql` mostra como criar os papéis no MySQL (`fraga_cadastro`, `fraga_consulta`).

**LGPD (RN14).** Os dados pessoais são nome, CPF/CNPJ, telefone, e-mail e endereço do cliente, e telefone do funcionário.

- Base legal: execução de contrato (o serviço) e consentimento registrado em `consentimento_lgpd`.
- Os relatórios gerenciais (G01–G12) não mostram CPF. Só G07, a cobrança, mostra o telefone.
- A auditoria A10 lista clientes sem consentimento registrado.
- A massa de dados é **fictícia**: nenhum nome, CPF, placa ou telefone de cliente real foi usado.
