# Dicionário de Dados — Centro Automotivo Fraga

> Turma GTI: dicionário em arquivo Markdown separado do README.
> [CONFIRMAR: conferir a ordem e os títulos das seções com o modelo `02-03g_Exemplo_Dicionario_Dados.pdf`, que não estava disponível quando este rascunho foi escrito.]

| Item | Valor |
| :--- | :--- |
| Banco | `fraga_oficina` |
| Versão do dicionário | 2.0 (Entrega 2) — 2026-10-28 |
| Fonte da verdade | [`docs/script.sql`](script.sql) — se o dicionário e o script divergirem, vale o script |
| Tabelas | 14 tabelas + 2 views (`vw_saldo_estoque`, `vw_total_os`) + 1 trigger (`tg_mov_saldo_nao_negativo`) |

## 1. Convenções

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

## 2. Relacionamentos

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

## 3. Fluxo de dados

1. **Atendimento.** O cliente chega ao balcão. A recepção busca pela placa (`veiculo.placa`). Se não houver cadastro, cria `cliente` (com `consentimento_lgpd`) e `veiculo`. Depois abre a `ordem_servico` com `km_entrada`, `problema_relatado` e `data_entrada`. Status: `aberta`.
2. **Avaliação e orçamento.** Um sócio avalia o carro e registra o `orcamento` com `valor_total`. Status: `aguardando_aprovacao`.
3. **Aprovação.** O cliente aprova (`orcamento.status = aprovado`, `data_decisao`) e a OS vai para `em_execucao`, com `id_mecanico`. Se o cliente recusar, a OS fica `cancelada`.
4. **Execução.** São lançados `item_servico` e `item_peca`. Cada peça da oficina gera uma `movimentacao_estoque` do tipo saída. O trigger bloqueia a saída se não houver saldo (RN10). Peça trazida pelo cliente não mexe no estoque.
5. **Liberação.** A OS fica `pronta`, a recepção avisa o cliente (`cliente_avisado = 1`) e o cliente paga (`pagamento`, uma ou várias linhas). Na retirada, a OS fica `entregue`, com `data_saida`, `garantia_ate` (+3 meses) e `numero_nota_fiscal`.
6. **Garantia.** Se o cliente volta dentro da garantia, a mesma OS recebe um `item_servico` com `retrabalho_garantia = 1` e valor 0, e uma observação (RN05).
7. **Compras.** Quando a peça fica abaixo do `estoque_minimo` (consulta G01), registra-se a `compra` e seus `item_compra`. No recebimento, a compra é conferida (`conferida = 1`) e cada item gera uma `movimentacao_estoque` do tipo entrada.
8. **Gestão.** As consultas G01–G12 e as views leem esses dados para os relatórios. As consultas A01–A10 conferem as regras.

## 4. Tabelas

Legenda das colunas: **Obrig.** = NOT NULL · **Chave** = PK / FK / UQ (único) · **Restrição** = CHECK, DEFAULT, ENUM.

### 4.1 `cliente`

- **Expressão formal:** `CLIENTE = @id_cliente + nome + tipo_pessoa + cpf_cnpj + telefone + (email) + endereco + data_cadastro + consentimento_lgpd`, com `endereco = logradouro + numero + bairro + cidade + uf + cep`
- **Leitura:** um cliente é a pessoa física ou jurídica atendida pela oficina. É identificado por um código e tem nome, documento único, telefone, e-mail opcional, endereço, data de cadastro e o registro do consentimento LGPD.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_cliente | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador do cliente |
| nome | VARCHAR(100) | sim | | índice `ix_cliente_nome` | Nome completo ou razão social |
| tipo_pessoa | ENUM('F','J') | sim | | DEFAULT 'F' | Física ou jurídica |
| cpf_cnpj | VARCHAR(18) | sim | UQ | CHECK: 14 caracteres se F (000.000.000-00), 18 se J | Documento; uma das buscas do balcão (RN08) |
| telefone | VARCHAR(15) | sim | | | Contato para avisar que o carro está pronto |
| email | VARCHAR(100) | não | | | E-mail, se o cliente informar |
| logradouro | VARCHAR(100) | sim | | | Rua/avenida (1FN: endereço decomposto) |
| numero | VARCHAR(10) | sim | | | Número do endereço |
| bairro | VARCHAR(60) | sim | | | Bairro |
| cidade | VARCHAR(60) | sim | | DEFAULT 'São Paulo' | Cidade |
| uf | CHAR(2) | sim | | DEFAULT 'SP' | Estado |
| cep | CHAR(9) | sim | | CHECK formato 00000-000 | CEP |
| data_cadastro | DATE | sim | | | Data do primeiro cadastro |
| consentimento_lgpd | TINYINT(1) | sim | | DEFAULT 0, CHECK 0/1 | 1 = cliente autorizou guardar os dados (RN14) |

### 4.2 `veiculo`

- **Expressão formal:** `VEICULO = @id_veiculo + id_cliente + placa + marca + modelo + ano + (motor) + km_atual`
- **Leitura:** um veículo é identificado pela placa e pertence a um único cliente por vez.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_veiculo | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador do veículo |
| id_cliente | INT UNSIGNED | sim | FK → cliente | ON DELETE RESTRICT | Dono atual (RN07) |
| placa | CHAR(7) | sim | UQ | CHECK padrão antigo ou Mercosul (AAA0A00) | Busca mais usada no balcão (RN08) |
| marca | VARCHAR(30) | sim | | | Montadora |
| modelo | VARCHAR(40) | sim | | | Modelo |
| ano | SMALLINT UNSIGNED | sim | | CHECK 1950–2100 | Ano de fabricação |
| motor | VARCHAR(10) | não | | | Motorização (1.0, 1.6, 2.0…) |
| km_atual | INT UNSIGNED | sim | | DEFAULT 0 | Última quilometragem registrada |

### 4.3 `funcionario`

- **Expressão formal:** `FUNCIONARIO = @id_funcionario + nome + funcao + (telefone) + pode_editar_cadastro + ativo`
- **Leitura:** um funcionário é sócio, recepcionista ou mecânico; só alguns têm permissão para cadastrar e alterar dados.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_funcionario | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| nome | VARCHAR(80) | sim | | | Nome |
| funcao | ENUM('socio','recepcionista','mecanico') | sim | | | Papel na oficina (RN15, RN16) |
| telefone | VARCHAR(15) | não | | | Contato |
| pode_editar_cadastro | TINYINT(1) | sim | | DEFAULT 0, CHECK 0/1 | 1 = pode cadastrar e alterar dados (RN06) |
| ativo | TINYINT(1) | sim | | DEFAULT 1 | 0 = desligado (mantém o histórico) |

### 4.4 `ordem_servico`

- **Expressão formal:** `ORDEM_SERVICO = @id_os + numero_os + id_veiculo + id_atendente + (id_mecanico) + km_entrada + problema_relatado + data_entrada + (data_previsao) + (data_saida) + status + cliente_avisado + (garantia_ate) + (numero_nota_fiscal) + (observacoes)`
- **Leitura:** uma OS registra o atendimento de um veículo, da entrada até a entrega, com quem atendeu, quem executou, as datas, o status, a garantia e a nota fiscal.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_os | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador interno |
| numero_os | INT UNSIGNED | sim | UQ | | Número impresso para o cliente (RN01) |
| id_veiculo | INT UNSIGNED | sim | FK → veiculo | RESTRICT | Veículo atendido |
| id_atendente | INT UNSIGNED | sim | FK → funcionario | RESTRICT | Quem abriu a OS (RN06) |
| id_mecanico | INT UNSIGNED | não | FK → funcionario | RESTRICT | Mecânico responsável (definido na execução) |
| km_entrada | INT UNSIGNED | sim | | | Km informada na entrada |
| problema_relatado | VARCHAR(255) | sim | | | Queixa do cliente |
| data_entrada | DATETIME | sim | | índice `ix_os_data_entrada` | Entrada; não muda em retrabalho (RN05) |
| data_previsao | DATE | não | | | Previsão de liberação informada ao cliente |
| data_saida | DATETIME | não | | CHECK ≥ data_entrada; obrigatória se entregue | Retirada do veículo |
| status | ENUM('aberta','aguardando_aprovacao','em_execucao','pronta','entregue','cancelada') | sim | | DEFAULT 'aberta', índice | Etapa da OS (substitui o antigo `pronto`) |
| cliente_avisado | TINYINT(1) | sim | | DEFAULT 0 | 1 = cliente avisado de que está pronto |
| garantia_ate | DATE | não | | | data_saida + 3 meses de garantia da mão de obra (RN04) |
| numero_nota_fiscal | VARCHAR(20) | não | | | NFS-e emitida em toda entrega (RN13) |
| observacoes | TEXT | não | | | Anotações, incluindo retorno em garantia (RN05) |

### 4.5 `orcamento`

- **Expressão formal:** `ORCAMENTO = @id_orcamento + id_os + id_funcionario + data_orcamento + valor_total + status + (data_decisao) + (observacoes)`
- **Leitura:** um orçamento é feito por um sócio para uma OS e fica pendente até o cliente aprovar ou recusar.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_orcamento | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| id_os | INT UNSIGNED | sim | FK → ordem_servico, UQ | ON DELETE CASCADE | Garante o 1 : 0..1 com a OS |
| id_funcionario | INT UNSIGNED | sim | FK → funcionario | RESTRICT | Sócio que orçou (RN15) |
| data_orcamento | DATETIME | sim | | | Quando foi feito |
| valor_total | DECIMAL(10,2) | sim | | CHECK ≥ 0 | Valor travado na OS (RN02) |
| status | ENUM('pendente','aprovado','recusado') | sim | | DEFAULT 'pendente' | Decisão do cliente |
| data_decisao | DATETIME | condicional | | CHECK: nula só se pendente | Quando o cliente decidiu |
| observacoes | VARCHAR(255) | não | | | Ex.: cliente vai trazer a peça |

### 4.6 `servico`

- **Expressão formal:** `SERVICO = @id_servico + nome_servico + (descricao) + valor_base + ativo`
- **Leitura:** catálogo dos serviços oferecidos, com preço de referência.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_servico | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| nome_servico | VARCHAR(80) | sim | UQ | | Nome no catálogo |
| descricao | VARCHAR(255) | não | | | Detalhe do serviço |
| valor_base | DECIMAL(10,2) | sim | | CHECK > 0 | Preço de referência (RN09) |
| ativo | TINYINT(1) | sim | | DEFAULT 1 | 0 = fora do catálogo |

### 4.7 `item_servico`

- **Expressão formal:** `ITEM_SERVICO = @id_item_servico + id_os + id_servico + quantidade + valor_cobrado + retrabalho_garantia`
- **Leitura:** cada serviço executado em uma OS, com o valor realmente cobrado.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_item_servico | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador (permite repetir o serviço na mesma OS em retrabalho) |
| id_os | INT UNSIGNED | sim | FK → ordem_servico | CASCADE | OS |
| id_servico | INT UNSIGNED | sim | FK → servico | RESTRICT | Serviço do catálogo |
| quantidade | TINYINT UNSIGNED | sim | | DEFAULT 1, CHECK > 0 | Quantidade |
| valor_cobrado | DECIMAL(10,2) | sim | | CHECK ≥ 0 | Preço praticado (pode ter desconto) |
| retrabalho_garantia | TINYINT(1) | sim | | DEFAULT 0; CHECK: se 1, valor = 0 | Serviço refeito em garantia (RN05) |

### 4.8 `peca`

- **Expressão formal:** `PECA = @id_peca + nome_peca + (codigo_fabricante) + unidade + valor_venda + estoque_minimo + ativo`
- **Leitura:** catálogo das peças que a oficina compra e revende. O saldo não fica aqui: é calculado pelas movimentações.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_peca | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| nome_peca | VARCHAR(80) | sim | | | Nome |
| codigo_fabricante | VARCHAR(30) | não | UQ | | Código da peça |
| unidade | ENUM('un','litro','jogo','kit') | sim | | DEFAULT 'un' | Unidade de estoque |
| valor_venda | DECIMAL(10,2) | sim | | CHECK ≥ 0 | Preço cobrado do cliente |
| estoque_minimo | INT UNSIGNED | sim | | DEFAULT 0 | Abaixo disso, comprar (RN12) |
| ativo | TINYINT(1) | sim | | DEFAULT 1 | 0 = não trabalha mais com a peça |

### 4.9 `item_peca`

- **Expressão formal:** `ITEM_PECA = @id_item_peca + id_os + [ id_peca | descricao_peca_cliente ] + origem + quantidade + valor_unitario`
- **Leitura:** cada peça usada em uma OS, da oficina (do catálogo) ou trazida pelo cliente (só descrição, sem valor e sem garantia).

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_item_peca | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| id_os | INT UNSIGNED | sim | FK → ordem_servico | CASCADE | OS |
| id_peca | INT UNSIGNED | condicional | FK → peca | CHECK: obrigatório se origem = oficina, nulo se cliente | Peça do catálogo |
| origem | ENUM('oficina','cliente') | sim | | DEFAULT 'oficina' | Quem forneceu a peça (P2, RN04) |
| descricao_peca_cliente | VARCHAR(100) | condicional | | CHECK: obrigatória se origem = cliente | Descrição da peça trazida |
| quantidade | INT UNSIGNED | sim | | CHECK > 0 | Quantidade |
| valor_unitario | DECIMAL(10,2) | sim | | DEFAULT 0; CHECK = 0 se origem = cliente | Preço praticado |

### 4.10 `fornecedor`

- **Expressão formal:** `FORNECEDOR = @id_fornecedor + razao_social + cnpj + telefone + (email) + ativo`
- **Leitura:** autopeças e distribuidores de quem a oficina compra.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_fornecedor | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| razao_social | VARCHAR(100) | sim | | | Nome da empresa |
| cnpj | CHAR(18) | sim | UQ | | CNPJ formatado |
| telefone | VARCHAR(15) | sim | | | Contato de vendas |
| email | VARCHAR(100) | não | | | E-mail |
| ativo | TINYINT(1) | sim | | DEFAULT 1 | Fornecedor em uso (RN11) |

### 4.11 `compra`

- **Expressão formal:** `COMPRA = @id_compra + id_fornecedor + id_funcionario + data_compra + (numero_nota_fiscal) + (data_recebimento) + conferida`
- **Leitura:** pedido de peças a um fornecedor, com o recebimento e a conferência.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_compra | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| id_fornecedor | INT UNSIGNED | sim | FK → fornecedor | RESTRICT | Fornecedor (RN11) |
| id_funcionario | INT UNSIGNED | sim | FK → funcionario | RESTRICT | Quem comprou |
| data_compra | DATE | sim | | | Data do pedido |
| numero_nota_fiscal | VARCHAR(20) | não | | | NF do fornecedor |
| data_recebimento | DATE | não | | CHECK ≥ data_compra | Quando chegou |
| conferida | TINYINT(1) | sim | | DEFAULT 0; CHECK: só 1 se recebida | Conferência feita (libera a entrada no estoque) |

### 4.12 `item_compra`

- **Expressão formal:** `ITEM_COMPRA = @(id_compra + id_peca) + quantidade + custo_unitario`
- **Leitura:** cada peça de uma compra, com quantidade e custo. A chave é composta: a mesma peça não se repete na mesma compra.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_compra | INT UNSIGNED | sim | PK, FK → compra | CASCADE | Compra |
| id_peca | INT UNSIGNED | sim | PK, FK → peca | RESTRICT | Peça |
| quantidade | INT UNSIGNED | sim | | CHECK > 0 | Quantidade comprada |
| custo_unitario | DECIMAL(10,2) | sim | | CHECK ≥ 0 | Custo pago ao fornecedor |

### 4.13 `movimentacao_estoque`

- **Expressão formal:** `MOVIMENTACAO_ESTOQUE = @id_movimentacao + id_peca + tipo + quantidade + data_movimentacao + [ id_compra | id_os | motivo ] + id_funcionario`
- **Leitura:** cada entrada ou saída de uma peça. A entrada vem de uma compra ou de um ajuste com motivo; a saída vai para uma OS ou é um ajuste com motivo.

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_movimentacao | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| id_peca | INT UNSIGNED | sim | FK → peca | índice `ix_mov_peca_data` | Peça |
| tipo | ENUM('entrada','saida') | sim | | trigger: saída ≤ saldo (RN10) | Sentido |
| quantidade | INT UNSIGNED | sim | | CHECK > 0 | Quantidade movimentada |
| data_movimentacao | DATETIME | sim | | | Quando |
| id_compra | INT UNSIGNED | condicional | FK → compra | CHECK: só em entrada | Compra que originou a entrada (RN11) |
| id_os | INT UNSIGNED | condicional | FK → ordem_servico | CHECK: só em saída | OS que consumiu a peça |
| id_funcionario | INT UNSIGNED | sim | FK → funcionario | | Quem lançou |
| motivo | VARCHAR(100) | condicional | | obrigatório se não houver compra/OS | Ajuste (ex.: inventário inicial) |

### 4.14 `pagamento`

- **Expressão formal:** `PAGAMENTO = @id_pagamento + id_os + data_pagamento + forma_pagamento + parcelas + valor_pago`
- **Leitura:** cada valor recebido por uma OS; uma OS pode ter vários (entrada, restante, parcial).

| Coluna | Tipo físico | Obrig. | Chave | Restrição | Descrição |
| :--- | :--- | :---: | :---: | :--- | :--- |
| id_pagamento | INT UNSIGNED | sim | PK | AUTO_INCREMENT | Identificador |
| id_os | INT UNSIGNED | sim | FK → ordem_servico | RESTRICT | OS paga |
| data_pagamento | DATETIME | sim | | | Quando |
| forma_pagamento | ENUM('dinheiro','pix','debito','credito') | sim | | | Forma (RN03) |
| parcelas | TINYINT UNSIGNED | sim | | DEFAULT 1; CHECK 1–12 e só >1 no crédito | Parcelamento |
| valor_pago | DECIMAL(10,2) | sim | | CHECK > 0 | Valor recebido |

O **saldo** que existia no dicionário da Entrega 1 saiu da tabela, porque é derivado (total da OS menos os pagamentos). Agora ele é calculado em `vw_total_os.saldo_devedor`.

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
