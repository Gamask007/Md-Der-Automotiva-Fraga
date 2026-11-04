-- =====================================================================
-- Centro Automotivo Fraga — Script SQL completo (Entrega 2)
-- SGBD: MySQL 8 (testado no MySQL 8.4) · charset utf8mb4 · collation utf8mb4_0900_ai_ci
-- Ordem: 1) CREATE DATABASE  2) CREATE TABLE + constraints  3) views e trigger
--        4) INSERT (massa fictícia)  5) SELECT com JOIN  6) UPDATE  7) DELETE
--        8) consultas gerenciais (G01–G12)  9) consultas de auditoria (A01–A10)
-- Executar do zero: o script apaga e recria o banco fraga_oficina.
-- Todos os nomes, CPFs, placas e telefones da massa são FICTÍCIOS.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) CREATE DATABASE
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS fraga_oficina;
CREATE DATABASE fraga_oficina
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE fraga_oficina;

-- ---------------------------------------------------------------------
-- 2) CREATE TABLE + constraints (PK, FK, NOT NULL, UNIQUE, CHECK, DEFAULT)
--    Ordem: primeiro as tabelas sem FK, depois as que dependem delas.
-- ---------------------------------------------------------------------

-- Funcionários da oficina (sócios, recepção e mecânicos) — RN06, RN15, RN16
CREATE TABLE funcionario (
  id_funcionario        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nome                  VARCHAR(80)   NOT NULL,
  funcao                ENUM('socio','recepcionista','mecanico') NOT NULL,
  telefone              VARCHAR(15)   NULL,
  pode_editar_cadastro  TINYINT(1)    NOT NULL DEFAULT 0,
  ativo                 TINYINT(1)    NOT NULL DEFAULT 1,
  CONSTRAINT pk_funcionario PRIMARY KEY (id_funcionario),
  CONSTRAINT ck_funcionario_flags CHECK (pode_editar_cadastro IN (0,1) AND ativo IN (0,1))
);

-- Clientes (pessoa física ou jurídica) — RN08, RN14
CREATE TABLE cliente (
  id_cliente          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nome                VARCHAR(100)  NOT NULL,
  tipo_pessoa         ENUM('F','J') NOT NULL DEFAULT 'F',
  cpf_cnpj            VARCHAR(18)   NOT NULL,
  telefone            VARCHAR(15)   NOT NULL,
  email               VARCHAR(100)  NULL,
  logradouro          VARCHAR(100)  NOT NULL,
  numero              VARCHAR(10)   NOT NULL,
  bairro              VARCHAR(60)   NOT NULL,
  cidade              VARCHAR(60)   NOT NULL DEFAULT 'São Paulo',
  uf                  CHAR(2)       NOT NULL DEFAULT 'SP',
  cep                 CHAR(9)       NOT NULL,
  data_cadastro       DATE          NOT NULL,
  consentimento_lgpd  TINYINT(1)    NOT NULL DEFAULT 0,
  CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
  CONSTRAINT uq_cliente_cpf_cnpj UNIQUE (cpf_cnpj),
  CONSTRAINT ck_cliente_doc CHECK (
    (tipo_pessoa = 'F' AND CHAR_LENGTH(cpf_cnpj) = 14) OR
    (tipo_pessoa = 'J' AND CHAR_LENGTH(cpf_cnpj) = 18)),
  CONSTRAINT ck_cliente_cep CHECK (cep REGEXP '^[0-9]{5}-[0-9]{3}$'),
  CONSTRAINT ck_cliente_lgpd CHECK (consentimento_lgpd IN (0,1))
);
CREATE INDEX ix_cliente_nome ON cliente (nome);

-- Catálogo de serviços — RN09
CREATE TABLE servico (
  id_servico    INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  nome_servico  VARCHAR(80)    NOT NULL,
  descricao     VARCHAR(255)   NULL,
  valor_base    DECIMAL(10,2)  NOT NULL,
  ativo         TINYINT(1)     NOT NULL DEFAULT 1,
  CONSTRAINT pk_servico PRIMARY KEY (id_servico),
  CONSTRAINT uq_servico_nome UNIQUE (nome_servico),
  CONSTRAINT ck_servico_valor CHECK (valor_base > 0)
);

-- Catálogo de peças da oficina (o saldo vem de movimentacao_estoque) — RN10, RN12
CREATE TABLE peca (
  id_peca            INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  nome_peca          VARCHAR(80)    NOT NULL,
  codigo_fabricante  VARCHAR(30)    NULL,
  unidade            ENUM('un','litro','jogo','kit') NOT NULL DEFAULT 'un',
  valor_venda        DECIMAL(10,2)  NOT NULL,
  estoque_minimo     INT UNSIGNED   NOT NULL DEFAULT 0,
  ativo              TINYINT(1)     NOT NULL DEFAULT 1,
  CONSTRAINT pk_peca PRIMARY KEY (id_peca),
  CONSTRAINT uq_peca_codigo UNIQUE (codigo_fabricante),
  CONSTRAINT ck_peca_valor CHECK (valor_venda >= 0)
);

-- Fornecedores (autopeças e distribuidores) — RN11
CREATE TABLE fornecedor (
  id_fornecedor  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  razao_social   VARCHAR(100)  NOT NULL,
  cnpj           CHAR(18)      NOT NULL,
  telefone       VARCHAR(15)   NOT NULL,
  email          VARCHAR(100)  NULL,
  ativo          TINYINT(1)    NOT NULL DEFAULT 1,
  CONSTRAINT pk_fornecedor PRIMARY KEY (id_fornecedor),
  CONSTRAINT uq_fornecedor_cnpj UNIQUE (cnpj)
);

-- Veículos: cada veículo pertence a um cliente por vez — RN07, RN08
CREATE TABLE veiculo (
  id_veiculo  INT UNSIGNED       NOT NULL AUTO_INCREMENT,
  id_cliente  INT UNSIGNED       NOT NULL,
  placa       CHAR(7)            NOT NULL,
  marca       VARCHAR(30)        NOT NULL,
  modelo      VARCHAR(40)        NOT NULL,
  ano         SMALLINT UNSIGNED  NOT NULL,
  motor       VARCHAR(10)        NULL,
  km_atual    INT UNSIGNED       NOT NULL DEFAULT 0,
  CONSTRAINT pk_veiculo PRIMARY KEY (id_veiculo),
  CONSTRAINT uq_veiculo_placa UNIQUE (placa),
  CONSTRAINT fk_veiculo_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_veiculo_placa CHECK (placa REGEXP '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
  CONSTRAINT ck_veiculo_ano CHECK (ano BETWEEN 1950 AND 2100)
);

-- Ordem de serviço: entidade central do atendimento — RN01, RN04, RN05, RN13
CREATE TABLE ordem_servico (
  id_os               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  numero_os           INT UNSIGNED  NOT NULL,
  id_veiculo          INT UNSIGNED  NOT NULL,
  id_atendente        INT UNSIGNED  NOT NULL,
  id_mecanico         INT UNSIGNED  NULL,
  km_entrada          INT UNSIGNED  NOT NULL,
  problema_relatado   VARCHAR(255)  NOT NULL,
  data_entrada        DATETIME      NOT NULL,
  data_previsao       DATE          NULL,
  data_saida          DATETIME      NULL,
  status              ENUM('aberta','aguardando_aprovacao','em_execucao','pronta','entregue','cancelada')
                                    NOT NULL DEFAULT 'aberta',
  cliente_avisado     TINYINT(1)    NOT NULL DEFAULT 0,
  garantia_ate        DATE          NULL,
  numero_nota_fiscal  VARCHAR(20)   NULL,
  observacoes         TEXT          NULL,
  CONSTRAINT pk_ordem_servico PRIMARY KEY (id_os),
  CONSTRAINT uq_os_numero UNIQUE (numero_os),
  CONSTRAINT fk_os_veiculo FOREIGN KEY (id_veiculo) REFERENCES veiculo (id_veiculo)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_os_atendente FOREIGN KEY (id_atendente) REFERENCES funcionario (id_funcionario)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_os_mecanico FOREIGN KEY (id_mecanico) REFERENCES funcionario (id_funcionario)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_os_datas CHECK (data_saida IS NULL OR data_saida >= data_entrada),
  CONSTRAINT ck_os_entregue CHECK (status <> 'entregue' OR data_saida IS NOT NULL),
  CONSTRAINT ck_os_avisado CHECK (cliente_avisado IN (0,1))
);
CREATE INDEX ix_os_data_entrada ON ordem_servico (data_entrada);
CREATE INDEX ix_os_status ON ordem_servico (status);

-- Orçamento: no máximo um por OS (1 : 0..1) — RN02, RN15
CREATE TABLE orcamento (
  id_orcamento    INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  id_os           INT UNSIGNED   NOT NULL,
  id_funcionario  INT UNSIGNED   NOT NULL,
  data_orcamento  DATETIME       NOT NULL,
  valor_total     DECIMAL(10,2)  NOT NULL,
  status          ENUM('pendente','aprovado','recusado') NOT NULL DEFAULT 'pendente',
  data_decisao    DATETIME       NULL,
  observacoes     VARCHAR(255)   NULL,
  CONSTRAINT pk_orcamento PRIMARY KEY (id_orcamento),
  CONSTRAINT uq_orcamento_os UNIQUE (id_os),
  CONSTRAINT fk_orcamento_os FOREIGN KEY (id_os) REFERENCES ordem_servico (id_os)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_orcamento_funcionario FOREIGN KEY (id_funcionario) REFERENCES funcionario (id_funcionario)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_orcamento_valor CHECK (valor_total >= 0),
  CONSTRAINT ck_orcamento_decisao CHECK (
    (status = 'pendente' AND data_decisao IS NULL) OR
    (status <> 'pendente' AND data_decisao IS NOT NULL))
);

-- Serviços executados em cada OS (resolve o N:N OS × SERVIÇO) — RN02, RN05
CREATE TABLE item_servico (
  id_item_servico      INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  id_os                INT UNSIGNED      NOT NULL,
  id_servico           INT UNSIGNED      NOT NULL,
  quantidade           TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  valor_cobrado        DECIMAL(10,2)     NOT NULL,
  retrabalho_garantia  TINYINT(1)        NOT NULL DEFAULT 0,
  CONSTRAINT pk_item_servico PRIMARY KEY (id_item_servico),
  CONSTRAINT fk_item_servico_os FOREIGN KEY (id_os) REFERENCES ordem_servico (id_os)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_item_servico_servico FOREIGN KEY (id_servico) REFERENCES servico (id_servico)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_item_servico_qtd CHECK (quantidade > 0),
  CONSTRAINT ck_item_servico_valor CHECK (valor_cobrado >= 0),
  CONSTRAINT ck_item_servico_retrabalho CHECK (retrabalho_garantia = 0 OR valor_cobrado = 0)
);

-- Peças usadas em cada OS, da oficina ou trazidas pelo cliente — RN04, RN10
CREATE TABLE item_peca (
  id_item_peca           INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  id_os                  INT UNSIGNED   NOT NULL,
  id_peca                INT UNSIGNED   NULL,
  origem                 ENUM('oficina','cliente') NOT NULL DEFAULT 'oficina',
  descricao_peca_cliente VARCHAR(100)   NULL,
  quantidade             INT UNSIGNED   NOT NULL,
  valor_unitario         DECIMAL(10,2)  NOT NULL DEFAULT 0,
  CONSTRAINT pk_item_peca PRIMARY KEY (id_item_peca),
  CONSTRAINT fk_item_peca_os FOREIGN KEY (id_os) REFERENCES ordem_servico (id_os)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_item_peca_peca FOREIGN KEY (id_peca) REFERENCES peca (id_peca)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT ck_item_peca_qtd CHECK (quantidade > 0),
  CONSTRAINT ck_item_peca_origem CHECK (
    (origem = 'oficina' AND id_peca IS NOT NULL AND descricao_peca_cliente IS NULL) OR
    (origem = 'cliente' AND id_peca IS NULL AND descricao_peca_cliente IS NOT NULL AND valor_unitario = 0))
);

-- Compras de peças junto a fornecedores — RN11
CREATE TABLE compra (
  id_compra           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_fornecedor       INT UNSIGNED  NOT NULL,
  id_funcionario      INT UNSIGNED  NOT NULL,
  data_compra         DATE          NOT NULL,
  numero_nota_fiscal  VARCHAR(20)   NULL,
  data_recebimento    DATE          NULL,
  conferida           TINYINT(1)    NOT NULL DEFAULT 0,
  CONSTRAINT pk_compra PRIMARY KEY (id_compra),
  CONSTRAINT fk_compra_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES fornecedor (id_fornecedor)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_compra_funcionario FOREIGN KEY (id_funcionario) REFERENCES funcionario (id_funcionario)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_compra_datas CHECK (data_recebimento IS NULL OR data_recebimento >= data_compra),
  CONSTRAINT ck_compra_conferida CHECK (conferida = 0 OR data_recebimento IS NOT NULL)
);

-- Itens de cada compra (N:N COMPRA × PEÇA, chave primária composta)
CREATE TABLE item_compra (
  id_compra       INT UNSIGNED   NOT NULL,
  id_peca         INT UNSIGNED   NOT NULL,
  quantidade      INT UNSIGNED   NOT NULL,
  custo_unitario  DECIMAL(10,2)  NOT NULL,
  CONSTRAINT pk_item_compra PRIMARY KEY (id_compra, id_peca),
  CONSTRAINT fk_item_compra_compra FOREIGN KEY (id_compra) REFERENCES compra (id_compra)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_item_compra_peca FOREIGN KEY (id_peca) REFERENCES peca (id_peca)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_item_compra_qtd CHECK (quantidade > 0),
  CONSTRAINT ck_item_compra_custo CHECK (custo_unitario >= 0)
);

-- Entradas e saídas de estoque: o saldo de cada peça é a soma destas linhas — RN10, RN11
CREATE TABLE movimentacao_estoque (
  id_movimentacao    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_peca            INT UNSIGNED  NOT NULL,
  tipo               ENUM('entrada','saida') NOT NULL,
  quantidade         INT UNSIGNED  NOT NULL,
  data_movimentacao  DATETIME      NOT NULL,
  id_compra          INT UNSIGNED  NULL,
  id_os              INT UNSIGNED  NULL,
  id_funcionario     INT UNSIGNED  NOT NULL,
  motivo             VARCHAR(100)  NULL,
  CONSTRAINT pk_movimentacao_estoque PRIMARY KEY (id_movimentacao),
  CONSTRAINT fk_mov_peca FOREIGN KEY (id_peca) REFERENCES peca (id_peca)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_mov_compra FOREIGN KEY (id_compra) REFERENCES compra (id_compra)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_mov_os FOREIGN KEY (id_os) REFERENCES ordem_servico (id_os)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_mov_funcionario FOREIGN KEY (id_funcionario) REFERENCES funcionario (id_funcionario)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT ck_mov_qtd CHECK (quantidade > 0),
  CONSTRAINT ck_mov_origem CHECK (
    (tipo = 'entrada' AND id_os IS NULL AND (id_compra IS NOT NULL OR motivo IS NOT NULL)) OR
    (tipo = 'saida' AND id_compra IS NULL AND (id_os IS NOT NULL OR motivo IS NOT NULL)))
);
CREATE INDEX ix_mov_peca_data ON movimentacao_estoque (id_peca, data_movimentacao);

-- Pagamentos de cada OS (permite entrada + restante e parcelamento) — RN03
CREATE TABLE pagamento (
  id_pagamento     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  id_os            INT UNSIGNED      NOT NULL,
  data_pagamento   DATETIME          NOT NULL,
  forma_pagamento  ENUM('dinheiro','pix','debito','credito') NOT NULL,
  parcelas         TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  valor_pago       DECIMAL(10,2)     NOT NULL,
  CONSTRAINT pk_pagamento PRIMARY KEY (id_pagamento),
  CONSTRAINT fk_pagamento_os FOREIGN KEY (id_os) REFERENCES ordem_servico (id_os)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_pagamento_valor CHECK (valor_pago > 0),
  CONSTRAINT ck_pagamento_parcelas CHECK (
    parcelas BETWEEN 1 AND 12 AND (forma_pagamento = 'credito' OR parcelas = 1))
);

-- ---------------------------------------------------------------------
-- 3) Views e trigger
-- ---------------------------------------------------------------------

-- Saldo atual de cada peça = entradas − saídas (não é guardado em coluna: 3FN)
CREATE VIEW vw_saldo_estoque AS
SELECT p.id_peca,
       p.nome_peca,
       CAST(p.estoque_minimo AS SIGNED) AS estoque_minimo,   -- SIGNED: permite contas como saldo - estoque_minimo
       CAST(COALESCE(SUM(CASE m.tipo WHEN 'entrada' THEN CAST(m.quantidade AS SIGNED)
                                     ELSE -CAST(m.quantidade AS SIGNED) END), 0) AS SIGNED) AS saldo
FROM peca p
LEFT JOIN movimentacao_estoque m ON m.id_peca = p.id_peca
GROUP BY p.id_peca, p.nome_peca, p.estoque_minimo;

-- Totais de cada OS: serviços + peças da oficina, valor pago e saldo devedor (calculados)
CREATE VIEW vw_total_os AS
SELECT os.id_os,
       os.numero_os,
       COALESCE(s.total_servicos, 0) AS total_servicos,
       COALESCE(pc.total_pecas, 0)   AS total_pecas,
       COALESCE(s.total_servicos, 0) + COALESCE(pc.total_pecas, 0) AS total_os,
       COALESCE(pg.total_pago, 0)    AS total_pago,
       COALESCE(s.total_servicos, 0) + COALESCE(pc.total_pecas, 0) - COALESCE(pg.total_pago, 0) AS saldo_devedor
FROM ordem_servico os
LEFT JOIN (SELECT id_os, SUM(quantidade * valor_cobrado) AS total_servicos
           FROM item_servico GROUP BY id_os) s  ON s.id_os = os.id_os
LEFT JOIN (SELECT id_os, SUM(quantidade * valor_unitario) AS total_pecas
           FROM item_peca WHERE origem = 'oficina' GROUP BY id_os) pc ON pc.id_os = os.id_os
LEFT JOIN (SELECT id_os, SUM(valor_pago) AS total_pago
           FROM pagamento GROUP BY id_os) pg ON pg.id_os = os.id_os;

-- RN10: não deixa sair do estoque mais do que o saldo da peça
DELIMITER $$
CREATE TRIGGER tg_mov_saldo_nao_negativo
BEFORE INSERT ON movimentacao_estoque
FOR EACH ROW
BEGIN
  DECLARE v_saldo INT;
  IF NEW.tipo = 'saida' THEN
    SELECT COALESCE(SUM(CASE tipo WHEN 'entrada' THEN CAST(quantidade AS SIGNED)
                                  ELSE -CAST(quantidade AS SIGNED) END), 0)
      INTO v_saldo
      FROM movimentacao_estoque
     WHERE id_peca = NEW.id_peca;
    IF v_saldo < NEW.quantidade THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN10: saldo insuficiente em estoque para esta saída';
    END IF;
  END IF;
END$$
DELIMITER ;

-- RN06 (opcional — exige privilégio de criar usuários; no laboratório pode ficar comentado)
-- CREATE ROLE IF NOT EXISTS 'fraga_cadastro', 'fraga_consulta';
-- GRANT SELECT, INSERT, UPDATE ON fraga_oficina.* TO 'fraga_cadastro';
-- GRANT SELECT ON fraga_oficina.* TO 'fraga_consulta';
-- CREATE USER IF NOT EXISTS 'recepcao'@'localhost' IDENTIFIED BY 'trocar-esta-senha';
-- GRANT 'fraga_cadastro' TO 'recepcao'@'localhost';

-- ---------------------------------------------------------------------
-- 4) INSERT — massa de dados fictícia (setembro/2026, ~1 mês de operação)
--    Gerada por docs/gerar_massa.py (semente fixa). Não editar à mão:
--    rode `python docs/gerar_massa.py` para regenerar este bloco.
-- ---------------------------------------------------------------------
-- [MASSA INICIO]
-- Volumes (setembro/2026): justificativa no README, seção 4

INSERT INTO funcionario (nome, funcao, telefone, pode_editar_cadastro, ativo) VALUES
  ('Paulo Henrique Fraga', 'socio', '(11) 92951-6234', 0, 1),
  ('Marcos Antônio Lima', 'socio', '(11) 99233-9385', 1, 1),
  ('Renato Carvalho Dias', 'socio', '(11) 92681-4658', 0, 1),
  ('Nicolau Ferreira Souza', 'recepcionista', '(11) 97891-9975', 1, 1),
  ('Sérgio Batista Rocha', 'mecanico', '(11) 99042-8226', 0, 1),
  ('Caio Mendes Pereira', 'mecanico', '(11) 94931-1041', 0, 1),
  ('Jonas Almeida Prado', 'mecanico', '(11) 92322-2814', 0, 1),
  ('Iago Nascimento Reis', 'mecanico', '(11) 95706-2606', 0, 1),
  ('Leandro Moraes Pinto', 'mecanico', '(11) 98367-1188', 0, 1);

INSERT INTO cliente (nome, tipo_pessoa, cpf_cnpj, telefone, email, logradouro, numero, bairro, cidade, uf, cep, data_cadastro, consentimento_lgpd) VALUES
  ('Ricardo Oliveira Araújo', 'F', '753.645.568-24', '(11) 99815-5786', NULL, 'Rua Pedro Bueno', '1883', 'Cidade Líder', 'São Paulo', 'SP', '08282-720', '2022-08-20', 1),
  ('Natália Mendes Almeida', 'F', '940.557.616-00', '(11) 99045-7523', 'cliente2@email.exemplo', 'Av. Líder', '1069', 'Jardim Helena', 'São Paulo', 'SP', '08272-948', '2017-08-11', 1),
  ('Tadeu Souza Cardoso', 'F', '788.093.208-91', '(11) 98898-4750', 'cliente3@email.exemplo', 'Rua Arraial de São Bartolomeu', '1881', 'Guaianases', 'São Paulo', 'SP', '08291-951', '2024-08-18', 1),
  ('Cíntia Alves Gomes', 'F', '848.648.876-16', '(11) 93455-8507', NULL, 'Av. Líder', '2015', 'Vila Carmosina', 'São Paulo', 'SP', '08225-266', '2021-01-12', 1),
  ('Elaine Souza Rocha', 'F', '778.768.045-86', '(11) 93999-7975', 'cliente5@email.exemplo', 'Av. Pires do Rio', '1972', 'Itaquera', 'São Paulo', 'SP', '08283-272', '2020-10-21', 1),
  ('Ana Rocha Barros', 'F', '751.362.701-01', '(11) 94257-5060', 'cliente6@email.exemplo', 'Rua Arraial de São Bartolomeu', '192', 'Artur Alvim', 'São Paulo', 'SP', '08234-684', '2016-11-11', 1),
  ('Olívia Almeida Barros', 'F', '520.599.728-17', '(11) 99269-5762', 'cliente7@email.exemplo', 'Rua Arraial de São Bartolomeu', '1721', 'Cidade Líder', 'São Paulo', 'SP', '08217-802', '2017-12-10', 1),
  ('Ana Souza Martins', 'F', '948.662.836-02', '(11) 96685-6790', NULL, 'Av. Osvaldo Pucci', '114', 'Artur Alvim', 'São Paulo', 'SP', '08260-335', '2016-08-24', 0),
  ('Jorge Barros Nunes', 'F', '475.177.992-31', '(11) 96511-8517', 'cliente9@email.exemplo', 'Rua Ernesto Mazzei', '965', 'Itaquera', 'São Paulo', 'SP', '08270-408', '2019-08-23', 1),
  ('Vanessa Silva Rodrigues', 'F', '032.080.737-12', '(11) 99468-3256', 'cliente10@email.exemplo', 'Av. Jacu-Pêssego', '771', 'Jardim Helena', 'São Paulo', 'SP', '08234-435', '2019-11-27', 1),
  ('Elaine Almeida Batista', 'F', '861.642.524-15', '(11) 93899-6337', NULL, 'Av. Líder', '1984', 'Guaianases', 'São Paulo', 'SP', '08215-539', '2024-04-28', 1),
  ('Bento Mendes Moreira', 'F', '841.330.175-01', '(11) 96766-3568', 'cliente12@email.exemplo', 'Av. Itaquera', '2311', 'Artur Alvim', 'São Paulo', 'SP', '08227-112', '2019-02-03', 1),
  ('Tadeu Mendes Rodrigues', 'F', '948.939.494-70', '(11) 92579-8144', 'cliente13@email.exemplo', 'Av. Jacu-Pêssego', '444', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08297-364', '2017-04-11', 1),
  ('Karina Lima Lima', 'F', '218.549.145-88', '(11) 95211-7791', NULL, 'Av. Osvaldo Pucci', '244', 'Itaquera', 'São Paulo', 'SP', '08230-023', '2016-05-30', 1),
  ('Freitas Serviços Ltda.', 'J', '41.189.557/0001-08', '(11) 96178-4532', 'cliente15@email.exemplo', 'Rua Ernesto Mazzei', '1905', 'Jardim Helena', 'São Paulo', 'SP', '08286-899', '2015-11-08', 1),
  ('Bruno Gomes Cardoso', 'F', '158.464.506-79', '(11) 93004-5865', NULL, 'Rua Virgínia Ferni', '1316', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08269-979', '2022-05-31', 1),
  ('Carla Rodrigues Nunes', 'F', '538.012.911-03', '(11) 95951-1471', 'cliente17@email.exemplo', 'Rua Virgínia Ferni', '2378', 'Cidade Líder', 'São Paulo', 'SP', '08245-425', '2022-12-10', 1),
  ('Tadeu Cardoso Mendes', 'F', '663.632.280-26', '(11) 93419-4739', 'cliente18@email.exemplo', 'Av. Osvaldo Pucci', '77', 'José Bonifácio', 'São Paulo', 'SP', '08269-490', '2023-11-26', 1),
  ('Sabrina Nunes Lima', 'F', '645.291.280-16', '(11) 96201-1921', 'cliente19@email.exemplo', 'Rua Antônio Thadeo', '56', 'Parque do Carmo', 'São Paulo', 'SP', '08260-059', '2022-08-23', 1),
  ('Mariana Ribeiro Ribeiro', 'F', '382.653.845-56', '(11) 99991-8767', 'cliente20@email.exemplo', 'Rua Antônio Thadeo', '2388', 'José Bonifácio', 'São Paulo', 'SP', '08224-162', '2025-04-20', 1),
  ('Felipe Gomes Ribeiro', 'F', '627.058.602-07', '(11) 92650-1300', NULL, 'Av. Líder', '899', 'José Bonifácio', 'São Paulo', 'SP', '08273-045', '2020-12-11', 1),
  ('Zeca Costa Mendes', 'F', '668.828.112-02', '(11) 94109-3657', NULL, 'Rua Pedro Bueno', '1219', 'Artur Alvim', 'São Paulo', 'SP', '08236-365', '2020-11-11', 1),
  ('Karina Araújo Nunes', 'F', '263.097.658-09', '(11) 99832-3371', NULL, 'Av. Jacu-Pêssego', '126', 'Itaquera', 'São Paulo', 'SP', '08265-683', '2015-08-30', 1),
  ('Patrícia Pereira Rodrigues', 'F', '051.543.829-43', '(11) 98939-2759', 'cliente24@email.exemplo', 'Av. Pires do Rio', '309', 'Jardim Helena', 'São Paulo', 'SP', '08233-631', '2017-05-20', 1),
  ('Wagner Moreira Rocha', 'F', '415.771.883-65', '(11) 92439-9107', NULL, 'Rua Pedro Bueno', '1096', 'Parque do Carmo', 'São Paulo', 'SP', '08221-332', '2022-09-28', 1),
  ('Mariana Rocha Pereira', 'F', '688.557.652-21', '(11) 96736-7712', 'cliente26@email.exemplo', 'Rua Ernesto Mazzei', '1573', 'Parque do Carmo', 'São Paulo', 'SP', '08219-452', '2022-10-26', 1),
  ('Quésia Rodrigues Mendes', 'F', '926.451.547-00', '(11) 93350-3019', NULL, 'Rua Pedro Bueno', '1212', 'Guaianases', 'São Paulo', 'SP', '08281-410', '2021-01-05', 1),
  ('Ingrid Alves Carvalho', 'F', '608.565.178-36', '(11) 91983-7549', 'cliente28@email.exemplo', 'Av. Pires do Rio', '718', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08234-572', '2022-11-24', 1),
  ('Ana Santos Batista', 'F', '425.996.775-48', '(11) 95401-6351', 'cliente29@email.exemplo', 'Av. Osvaldo Pucci', '866', 'Guaianases', 'São Paulo', 'SP', '08265-283', '2019-12-07', 1),
  ('Rodrigues Entregas Ltda.', 'J', '95.183.801/0001-46', '(11) 94381-3798', 'cliente30@email.exemplo', 'Av. Pires do Rio', '1277', 'Itaquera', 'São Paulo', 'SP', '08272-427', '2019-12-03', 1),
  ('Lucas Mendes Araújo', 'F', '898.210.460-70', '(11) 98713-6591', 'cliente31@email.exemplo', 'Av. Itaquera', '1433', 'Vila Carmosina', 'São Paulo', 'SP', '08277-491', '2020-03-10', 1),
  ('Yasmin Lima Batista', 'F', '475.407.207-35', '(11) 95483-9393', NULL, 'Av. Pires do Rio', '1648', 'José Bonifácio', 'São Paulo', 'SP', '08227-595', '2025-06-15', 1),
  ('Hugo Nunes Freitas', 'F', '061.884.791-00', '(11) 96564-6899', 'cliente33@email.exemplo', 'Av. Jacu-Pêssego', '329', 'Artur Alvim', 'São Paulo', 'SP', '08222-777', '2022-04-17', 1),
  ('Pedro Alves Carvalho', 'F', '488.619.307-27', '(11) 93072-9416', 'cliente34@email.exemplo', 'Rua Gregório Ramalho', '1118', 'Guaianases', 'São Paulo', 'SP', '08217-572', '2026-05-24', 1),
  ('Lívia Cardoso Rodrigues', 'F', '556.898.329-10', '(11) 92000-1565', NULL, 'Rua Pedro Bueno', '1236', 'Cidade Líder', 'São Paulo', 'SP', '08217-273', '2018-03-25', 1),
  ('Bento Teixeira Freitas', 'F', '852.722.022-95', '(11) 91475-5925', 'cliente36@email.exemplo', 'Rua Gregório Ramalho', '2117', 'Vila Carmosina', 'São Paulo', 'SP', '08269-094', '2025-12-25', 1),
  ('Daniel Souza Ribeiro', 'F', '762.528.070-52', '(11) 91460-3683', NULL, 'Av. Líder', '793', 'Itaquera', 'São Paulo', 'SP', '08254-679', '2020-10-08', 1),
  ('Júlio Carvalho Araújo', 'F', '632.337.352-19', '(11) 96950-4427', 'cliente38@email.exemplo', 'Rua Pedro Bueno', '1814', 'Artur Alvim', 'São Paulo', 'SP', '08277-493', '2024-06-28', 1),
  ('Lucas Alves Teixeira', 'F', '133.115.921-07', '(11) 98010-1499', NULL, 'Av. Líder', '603', 'José Bonifácio', 'São Paulo', 'SP', '08236-756', '2024-09-21', 1),
  ('Isabela Souza Rodrigues', 'F', '560.787.457-51', '(11) 98471-7183', 'cliente40@email.exemplo', 'Rua Ernesto Mazzei', '2439', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08289-686', '2019-12-29', 1),
  ('Ingrid Souza Lima', 'F', '854.177.588-76', '(11) 91686-2150', NULL, 'Av. Líder', '1863', 'Itaquera', 'São Paulo', 'SP', '08249-818', '2021-08-28', 1),
  ('Bruno Souza Martins', 'F', '979.780.252-33', '(11) 95177-1298', NULL, 'Av. Osvaldo Pucci', '301', 'Artur Alvim', 'São Paulo', 'SP', '08215-750', '2017-01-22', 1),
  ('Pedro Nunes Costa', 'F', '524.735.736-11', '(11) 95083-4019', NULL, 'Rua Dr. Luís Aires', '782', 'Itaquera', 'São Paulo', 'SP', '08275-487', '2024-05-24', 1),
  ('Ingrid Rocha Rodrigues', 'F', '967.807.360-90', '(11) 99541-6142', NULL, 'Rua Pedro Bueno', '1778', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08245-616', '2021-08-10', 1),
  ('Oliveira Serviços Ltda.', 'J', '82.819.539/0001-31', '(11) 92819-2731', 'cliente45@email.exemplo', 'Rua Virgínia Ferni', '1652', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08231-201', '2018-10-25', 1),
  ('Carla Alves Cardoso', 'F', '042.845.142-02', '(11) 91582-6827', 'cliente46@email.exemplo', 'Av. Pires do Rio', '1922', 'Artur Alvim', 'São Paulo', 'SP', '08280-956', '2017-08-05', 1),
  ('Nelson Silva Gomes', 'F', '037.041.214-10', '(11) 95249-2168', 'cliente47@email.exemplo', 'Av. Pires do Rio', '2248', 'Cidade Líder', 'São Paulo', 'SP', '08270-650', '2015-12-24', 1),
  ('Júlio Martins Rocha', 'F', '898.370.853-04', '(11) 91247-7774', NULL, 'Rua Virgínia Ferni', '2286', 'Itaquera', 'São Paulo', 'SP', '08256-691', '2016-12-17', 1),
  ('Aline Lima Teixeira', 'F', '922.328.385-01', '(11) 91310-6641', 'cliente49@email.exemplo', 'Rua Arraial de São Bartolomeu', '543', 'Artur Alvim', 'São Paulo', 'SP', '08299-249', '2018-10-15', 1),
  ('Zeca Oliveira Cardoso', 'F', '725.278.120-82', '(11) 96547-9393', 'cliente50@email.exemplo', 'Av. Itaquera', '350', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08283-258', '2026-03-03', 1);
INSERT INTO cliente (nome, tipo_pessoa, cpf_cnpj, telefone, email, logradouro, numero, bairro, cidade, uf, cep, data_cadastro, consentimento_lgpd) VALUES
  ('Thiago Araújo Mendes', 'F', '316.349.992-90', '(11) 96612-3875', 'cliente51@email.exemplo', 'Av. Pires do Rio', '1886', 'Itaquera', 'São Paulo', 'SP', '08231-680', '2015-03-27', 1),
  ('Patrícia Nunes Gomes', 'F', '729.871.120-25', '(11) 95129-1332', 'cliente52@email.exemplo', 'Rua Dr. Luís Aires', '1220', 'Cidade Líder', 'São Paulo', 'SP', '08248-648', '2018-04-24', 1),
  ('Zeca Lima Rocha', 'F', '079.113.571-37', '(11) 95872-5110', 'cliente53@email.exemplo', 'Rua Dr. Luís Aires', '1691', 'Guaianases', 'São Paulo', 'SP', '08237-880', '2024-12-16', 1),
  ('Aline Pereira Cardoso', 'F', '521.980.334-45', '(11) 92663-4765', NULL, 'Rua Virgínia Ferni', '536', 'Vila Carmosina', 'São Paulo', 'SP', '08282-549', '2022-04-19', 1),
  ('Wagner Rocha Pereira', 'F', '639.848.864-46', '(11) 91613-4201', 'cliente55@email.exemplo', 'Rua Pedro Bueno', '705', 'Jardim Helena', 'São Paulo', 'SP', '08285-594', '2018-12-09', 1),
  ('Hugo Costa Mendes', 'F', '276.709.409-56', '(11) 94699-9763', 'cliente56@email.exemplo', 'Av. Líder', '1179', 'Artur Alvim', 'São Paulo', 'SP', '08244-851', '2021-09-06', 1),
  ('Patrícia Ribeiro Pereira', 'F', '568.306.866-52', '(11) 91477-2752', NULL, 'Rua Gregório Ramalho', '891', 'Cidade Líder', 'São Paulo', 'SP', '08262-632', '2023-06-23', 1),
  ('Felipe Souza Souza', 'F', '672.683.508-64', '(11) 98493-6685', NULL, 'Rua Antônio Thadeo', '2123', 'Itaquera', 'São Paulo', 'SP', '08253-240', '2019-11-16', 1),
  ('Gabriela Teixeira Souza', 'F', '540.115.276-02', '(11) 98957-6585', 'cliente59@email.exemplo', 'Rua Ernesto Mazzei', '751', 'Itaquera', 'São Paulo', 'SP', '08211-354', '2019-04-12', 1),
  ('Oliveira Transportes Ltda.', 'J', '32.771.862/0001-04', '(11) 92027-8238', 'cliente60@email.exemplo', 'Rua Dr. Luís Aires', '261', 'Guaianases', 'São Paulo', 'SP', '08260-359', '2025-05-27', 1),
  ('Pedro Carvalho Souza', 'F', '106.261.488-71', '(11) 91179-3320', 'cliente61@email.exemplo', 'Rua Ernesto Mazzei', '2493', 'José Bonifácio', 'São Paulo', 'SP', '08233-794', '2022-11-07', 1),
  ('Quésia Costa Carvalho', 'F', '613.516.199-77', '(11) 99581-3970', NULL, 'Av. Líder', '1726', 'José Bonifácio', 'São Paulo', 'SP', '08204-568', '2021-12-20', 1),
  ('Davi Ferreira Ribeiro', 'F', '948.746.439-57', '(11) 96100-2807', 'cliente63@email.exemplo', 'Rua Ernesto Mazzei', '1020', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08225-615', '2021-12-06', 1),
  ('Otávio Martins Moreira', 'F', '955.156.697-11', '(11) 98054-8420', 'cliente64@email.exemplo', 'Rua Ernesto Mazzei', '1338', 'Jardim Helena', 'São Paulo', 'SP', '08245-014', '2017-05-22', 1),
  ('Carla Freitas Silva', 'F', '565.470.567-91', '(11) 99924-1895', 'cliente65@email.exemplo', 'Rua Arraial de São Bartolomeu', '1365', 'Jardim Helena', 'São Paulo', 'SP', '08233-393', '2021-08-05', 1),
  ('Daniel Cardoso Ribeiro', 'F', '440.330.132-02', '(11) 99790-9456', NULL, 'Rua Antônio Thadeo', '232', 'José Bonifácio', 'São Paulo', 'SP', '08216-110', '2025-03-25', 1),
  ('Isabela Rocha Mendes', 'F', '631.111.960-97', '(11) 95703-7700', 'cliente67@email.exemplo', 'Av. Itaquera', '2290', 'Guaianases', 'São Paulo', 'SP', '08224-953', '2015-07-16', 1),
  ('Daniel Oliveira Rocha', 'F', '064.248.296-95', '(11) 98226-3407', 'cliente68@email.exemplo', 'Av. Osvaldo Pucci', '1187', 'Itaquera', 'São Paulo', 'SP', '08216-440', '2024-04-02', 1),
  ('Wellington Gomes Silva', 'F', '347.892.352-20', '(11) 97326-2262', NULL, 'Av. Itaquera', '1611', 'Itaquera', 'São Paulo', 'SP', '08201-375', '2017-04-24', 1),
  ('Thiago Mendes Mendes', 'F', '914.833.541-05', '(11) 92198-4688', 'cliente70@email.exemplo', 'Rua Dr. Luís Aires', '2296', 'Vila Carmosina', 'São Paulo', 'SP', '08217-174', '2017-06-30', 1),
  ('Yasmin Alves Alves', 'F', '238.416.497-00', '(11) 98761-2058', 'cliente71@email.exemplo', 'Rua Antônio Thadeo', '2448', 'Cidade Líder', 'São Paulo', 'SP', '08279-293', '2018-12-29', 1),
  ('Jorge Lima Rocha', 'F', '808.534.704-05', '(11) 92693-4405', 'cliente72@email.exemplo', 'Rua Pedro Bueno', '516', 'José Bonifácio', 'São Paulo', 'SP', '08286-841', '2023-10-22', 1),
  ('Simone Batista Carvalho', 'F', '617.544.201-68', '(11) 94318-9851', 'cliente73@email.exemplo', 'Av. Osvaldo Pucci', '133', 'Vila Carmosina', 'São Paulo', 'SP', '08225-028', '2017-01-07', 1),
  ('Olívia Santos Ribeiro', 'F', '514.786.589-67', '(11) 99005-8027', 'cliente74@email.exemplo', 'Av. Osvaldo Pucci', '1411', 'Vila Carmosina', 'São Paulo', 'SP', '08225-554', '2026-01-15', 1),
  ('Carvalho Entregas Ltda.', 'J', '48.856.810/0001-70', '(11) 91647-8740', 'cliente75@email.exemplo', 'Av. Jacu-Pêssego', '1947', 'Jardim Helena', 'São Paulo', 'SP', '08215-730', '2016-03-04', 1),
  ('Nelson Rocha Moreira', 'F', '514.136.334-12', '(11) 99642-8776', NULL, 'Av. Itaquera', '717', 'Jardim Helena', 'São Paulo', 'SP', '08282-135', '2015-03-15', 1),
  ('Lívia Carvalho Alves', 'F', '394.246.466-74', '(11) 97029-4524', NULL, 'Rua Ernesto Mazzei', '2236', 'Guaianases', 'São Paulo', 'SP', '08233-790', '2017-01-02', 1),
  ('Elaine Ferreira Pereira', 'F', '535.813.421-20', '(11) 97656-8643', 'cliente78@email.exemplo', 'Rua Dr. Luís Aires', '185', 'José Bonifácio', 'São Paulo', 'SP', '08292-906', '2020-01-22', 1),
  ('Hugo Carvalho Araújo', 'F', '410.475.168-53', '(11) 92960-5589', 'cliente79@email.exemplo', 'Rua Arraial de São Bartolomeu', '235', 'Artur Alvim', 'São Paulo', 'SP', '08216-253', '2022-01-19', 1),
  ('Karina Barros Lima', 'F', '595.349.404-10', '(11) 99483-2218', NULL, 'Av. Líder', '537', 'José Bonifácio', 'São Paulo', 'SP', '08234-407', '2025-10-15', 1),
  ('Lívia Silva Oliveira', 'F', '026.195.680-99', '(11) 91703-6136', 'cliente81@email.exemplo', 'Rua Antônio Thadeo', '546', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08202-501', '2016-03-24', 1),
  ('Gisele Alves Pereira', 'F', '009.170.392-11', '(11) 91538-4267', NULL, 'Av. Osvaldo Pucci', '1287', 'Artur Alvim', 'São Paulo', 'SP', '08264-488', '2015-11-14', 1),
  ('Pedro Ribeiro Oliveira', 'F', '781.661.146-31', '(11) 91465-5019', NULL, 'Av. Líder', '994', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08206-870', '2016-10-18', 1),
  ('Davi Oliveira Carvalho', 'F', '403.004.263-56', '(11) 96758-3921', NULL, 'Rua Ernesto Mazzei', '1012', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08210-910', '2026-01-17', 1),
  ('Fábio Silva Costa', 'F', '267.081.297-01', '(11) 93838-3777', 'cliente85@email.exemplo', 'Rua Gregório Ramalho', '2445', 'Artur Alvim', 'São Paulo', 'SP', '08208-752', '2026-03-10', 1),
  ('Henrique Ribeiro Mendes', 'F', '337.027.186-99', '(11) 92739-5784', NULL, 'Rua Dr. Luís Aires', '104', 'Jardim Helena', 'São Paulo', 'SP', '08260-843', '2017-09-09', 1),
  ('Vinícius Souza Martins', 'F', '554.850.663-30', '(11) 99490-3401', 'cliente87@email.exemplo', 'Av. Itaquera', '2392', 'Guaianases', 'São Paulo', 'SP', '08225-260', '2026-03-06', 1),
  ('Olívia Araújo Carvalho', 'F', '812.417.264-18', '(11) 99469-3784', 'cliente88@email.exemplo', 'Rua Ernesto Mazzei', '111', 'Cidade Líder', 'São Paulo', 'SP', '08201-540', '2023-11-15', 1),
  ('Ingrid Pereira Rocha', 'F', '242.204.262-72', '(11) 96977-1723', 'cliente89@email.exemplo', 'Rua Virgínia Ferni', '256', 'Itaquera', 'São Paulo', 'SP', '08269-533', '2015-07-26', 1),
  ('Rocha Serviços Ltda.', 'J', '98.704.151/0001-25', '(11) 94822-4785', 'cliente90@email.exemplo', 'Av. Pires do Rio', '596', 'Vila Carmosina', 'São Paulo', 'SP', '08222-393', '2016-03-22', 1),
  ('Wellington Santos Teixeira', 'F', '956.378.276-30', '(11) 97599-2789', NULL, 'Av. Jacu-Pêssego', '394', 'Parque do Carmo', 'São Paulo', 'SP', '08267-983', '2026-06-21', 1),
  ('Júlio Martins Batista', 'F', '560.700.223-35', '(11) 96478-4352', 'cliente92@email.exemplo', 'Rua Pedro Bueno', '917', 'Cidade Líder', 'São Paulo', 'SP', '08262-302', '2023-10-22', 1),
  ('Daniel Carvalho Alves', 'F', '655.013.510-99', '(11) 98774-2189', 'cliente93@email.exemplo', 'Rua Antônio Thadeo', '517', 'Cidade Líder', 'São Paulo', 'SP', '08297-929', '2025-11-13', 1),
  ('Carla Freitas Mendes', 'F', '433.516.585-40', '(11) 91261-2726', 'cliente94@email.exemplo', 'Av. Itaquera', '1049', 'Parque do Carmo', 'São Paulo', 'SP', '08213-396', '2024-02-12', 1),
  ('Gabriela Ribeiro Ferreira', 'F', '103.022.502-80', '(11) 92930-2378', NULL, 'Rua Pedro Bueno', '2188', 'Cidade Líder', 'São Paulo', 'SP', '08276-667', '2015-01-16', 1),
  ('Isabela Alves Nunes', 'F', '418.341.908-51', '(11) 92078-4720', 'cliente96@email.exemplo', 'Av. Itaquera', '550', 'Itaquera', 'São Paulo', 'SP', '08292-133', '2024-01-12', 1),
  ('Gisele Martins Santos', 'F', '223.863.787-72', '(11) 96891-5995', 'cliente97@email.exemplo', 'Av. Jacu-Pêssego', '1182', 'Jardim Helena', 'São Paulo', 'SP', '08266-704', '2021-06-26', 1),
  ('Ricardo Cardoso Ferreira', 'F', '542.427.641-54', '(11) 98284-7617', NULL, 'Rua Virgínia Ferni', '171', 'José Bonifácio', 'São Paulo', 'SP', '08295-478', '2025-12-29', 1),
  ('Simone Barros Martins', 'F', '139.360.550-84', '(11) 91176-7767', 'cliente99@email.exemplo', 'Av. Osvaldo Pucci', '1393', 'Jardim Helena', 'São Paulo', 'SP', '08233-712', '2023-03-06', 1),
  ('Fábio Rocha Souza', 'F', '333.879.268-98', '(11) 97574-5609', 'cliente100@email.exemplo', 'Rua Pedro Bueno', '1182', 'Jardim Helena', 'São Paulo', 'SP', '08276-312', '2015-03-25', 1);
INSERT INTO cliente (nome, tipo_pessoa, cpf_cnpj, telefone, email, logradouro, numero, bairro, cidade, uf, cep, data_cadastro, consentimento_lgpd) VALUES
  ('Isabela Carvalho Martins', 'F', '037.205.683-00', '(11) 97368-9254', 'cliente101@email.exemplo', 'Rua Ernesto Mazzei', '1573', 'Vila Carmosina', 'São Paulo', 'SP', '08210-418', '2015-02-03', 1),
  ('Márcio Carvalho Ferreira', 'F', '480.788.203-13', '(11) 99728-8233', NULL, 'Rua Virgínia Ferni', '2359', 'Vila Carmosina', 'São Paulo', 'SP', '08231-743', '2019-01-20', 1),
  ('Gisele Carvalho Moreira', 'F', '971.100.989-74', '(11) 99346-3093', NULL, 'Av. Jacu-Pêssego', '61', 'Guaianases', 'São Paulo', 'SP', '08202-964', '2015-07-03', 1),
  ('Gisele Nunes Rodrigues', 'F', '169.298.442-09', '(11) 93511-5530', 'cliente104@email.exemplo', 'Rua Pedro Bueno', '900', 'Itaquera', 'São Paulo', 'SP', '08259-794', '2016-02-24', 1),
  ('Souza Entregas Ltda.', 'J', '74.664.323/0001-16', '(11) 98334-3593', 'cliente105@email.exemplo', 'Rua Arraial de São Bartolomeu', '1183', 'Itaquera', 'São Paulo', 'SP', '08289-381', '2025-08-23', 1),
  ('Lucas Oliveira Mendes', 'F', '344.796.725-08', '(11) 94546-3757', 'cliente106@email.exemplo', 'Rua Arraial de São Bartolomeu', '531', 'Jardim Helena', 'São Paulo', 'SP', '08290-405', '2015-10-17', 1),
  ('Mariana Batista Souza', 'F', '869.227.138-18', '(11) 95474-9009', 'cliente107@email.exemplo', 'Rua Arraial de São Bartolomeu', '1531', 'Jardim Nossa Sra. do Carmo', 'São Paulo', 'SP', '08285-130', '2018-11-09', 1),
  ('Vinícius Martins Costa', 'F', '952.920.742-50', '(11) 94103-8693', 'cliente108@email.exemplo', 'Rua Arraial de São Bartolomeu', '2006', 'Jardim Helena', 'São Paulo', 'SP', '08227-303', '2026-02-14', 1),
  ('Eduarda Gomes Ribeiro', 'F', '526.064.501-40', '(11) 98047-6911', 'cliente109@email.exemplo', 'Rua Antônio Thadeo', '2193', 'José Bonifácio', 'São Paulo', 'SP', '08242-757', '2021-06-08', 1),
  ('Henrique Silva Souza', 'F', '007.485.148-99', '(11) 92048-7109', 'cliente110@email.exemplo', 'Rua Virgínia Ferni', '184', 'José Bonifácio', 'São Paulo', 'SP', '08297-698', '2019-08-24', 1);

INSERT INTO veiculo (id_cliente, placa, marca, modelo, ano, motor, km_atual) VALUES
  (1, 'OQX9C42', 'Fiat', 'Uno', 2025, '1.0', 16453),
  (2, 'DSW4033', 'Fiat', 'Strada', 2008, '1.4', 177475),
  (3, 'LPL9H80', 'Chevrolet', 'Celta', 2010, '1.0', 196388),
  (4, 'LJS9B21', 'Fiat', 'Strada', 2009, '1.3', 248619),
  (5, 'JST3009', 'Hyundai', 'HB20', 2024, '1.6', 36589),
  (6, 'GUM7872', 'Volkswagen', 'Gol', 2015, '1.6', 146055),
  (6, 'JEI4433', 'Fiat', 'Argo', 2021, '1.0', 72730),
  (7, 'BXM5166', 'Chevrolet', 'Onix', 2016, '1.4', 149831),
  (8, 'FRI6009', 'Chevrolet', 'Cruze', 2012, '1.4 T', 218220),
  (9, 'ULM3C47', 'Honda', 'Civic', 2014, '2.0', 133953),
  (10, 'WJF6382', 'Chevrolet', 'Prisma', 2008, '1.4', 227277),
  (11, 'HCO1934', 'Toyota', 'Corolla', 2017, '2.0', 131628),
  (12, 'OOO3286', 'Honda', 'Civic', 2008, '2.0', 237624),
  (12, 'JXZ1I66', 'Toyota', 'Corolla', 2010, '2.0', 216727),
  (13, 'BNT6029', 'Fiat', 'Strada', 2015, '1.3', 161002),
  (14, 'VLI1265', 'Volkswagen', 'Polo', 2014, '1.0 TSI', 194760),
  (15, 'MOR7D18', 'Honda', 'Fit', 2022, '1.5', 66756),
  (15, 'CFE2A64', 'Honda', 'Civic', 2020, '2.0', 77479),
  (16, 'RAZ5F80', 'Hyundai', 'HB20', 2018, '1.6', 85177),
  (17, 'PMQ7665', 'Renault', 'Logan', 2022, '1.6', 56061),
  (18, 'PTO5740', 'Renault', 'Sandero', 2020, '1.6', 93554),
  (18, 'XLL8J24', 'Chevrolet', 'Onix', 2021, '1.4', 62659),
  (19, 'XPQ3008', 'Ford', 'Fiesta', 2009, '1.6', 232767),
  (20, 'QOC7533', 'Volkswagen', 'Gol', 2016, '1.0', 156160),
  (21, 'EAC1856', 'Chevrolet', 'Cruze', 2016, '1.4 T', 95752),
  (22, 'OKB8005', 'Fiat', 'Mobi', 2009, '1.0', 184151),
  (23, 'WJL9511', 'Ford', 'Fiesta', 2022, '1.6', 55367),
  (24, 'FTG3617', 'Fiat', 'Argo', 2020, '1.3', 87955),
  (24, 'YDX3I40', 'Fiat', 'Strada', 2023, '1.3', 36469),
  (25, 'PUQ3451', 'Fiat', 'Argo', 2018, '1.3', 111385),
  (26, 'JOG3E11', 'Ford', 'Fiesta', 2017, '1.6', 118648),
  (27, 'PPD2H93', 'Volkswagen', 'Polo', 2019, '1.0 TSI', 77592),
  (28, 'JHB6835', 'Volkswagen', 'Polo', 2016, '1.0 TSI', 155161),
  (29, 'DJG5G73', 'Ford', 'EcoSport', 2013, '1.6', 151598),
  (30, 'UJW5960', 'Ford', 'EcoSport', 2014, '2.0', 162685),
  (30, 'RMM7F09', 'Volkswagen', 'Saveiro', 2010, '1.6', 252077),
  (31, 'UEM1110', 'Chevrolet', 'Prisma', 2012, '1.4', 131157),
  (32, 'RHL0922', 'Volkswagen', 'Gol', 2020, '1.6', 97051),
  (33, 'ERY5294', 'Fiat', 'Strada', 2009, '1.4', 257119),
  (34, 'CUQ0H02', 'Chevrolet', 'Cruze', 2008, '1.4 T', 216606),
  (35, 'KLK2489', 'Ford', 'Ka', 2010, '1.0', 188049),
  (36, 'QHB2F51', 'Volkswagen', 'Fox', 2016, '1.6', 137113),
  (36, 'QFH8H34', 'Volkswagen', 'Polo', 2009, '1.0 TSI', 230155),
  (37, 'WZA1378', 'Fiat', 'Uno', 2018, '1.0', 135514),
  (38, 'HKJ3733', 'Fiat', 'Mobi', 2022, '1.0', 50774),
  (39, 'CTS5079', 'Ford', 'Fiesta', 2016, '1.6', 120149),
  (40, 'COB6G11', 'Honda', 'Fit', 2013, '1.5', 185949),
  (41, 'AUH5418', 'Honda', 'Civic', 2025, '2.0', 16724),
  (42, 'QYN5B93', 'Ford', 'EcoSport', 2008, '1.6', 212613),
  (42, 'MDE3074', 'Toyota', 'Etios', 2025, '1.5', 18033);
INSERT INTO veiculo (id_cliente, placa, marca, modelo, ano, motor, km_atual) VALUES
  (43, 'OBX3503', 'Chevrolet', 'Onix', 2023, '1.0', 38556),
  (44, 'FOO2H53', 'Renault', 'Sandero', 2009, '1.6', 231031),
  (45, 'JHN0734', 'Volkswagen', 'Polo', 2018, '1.0 TSI', 86451),
  (45, 'PFM4C87', 'Fiat', 'Argo', 2009, '1.0', 195753),
  (46, 'ECM7051', 'Volkswagen', 'Gol', 2018, '1.6', 87530),
  (47, 'NAL1767', 'Honda', 'Fit', 2019, '1.5', 104344),
  (48, 'FST7A60', 'Hyundai', 'HB20', 2014, '1.0', 163216),
  (48, 'OKP6A06', 'Renault', 'Logan', 2011, '1.6', 165369),
  (49, 'JIO7965', 'Chevrolet', 'Celta', 2020, '1.0', 85682),
  (50, 'VYD7490', 'Ford', 'Fiesta', 2021, '1.6', 74816),
  (51, 'EGM9053', 'Honda', 'Civic', 2009, '2.0', 181701),
  (52, 'HOK7I35', 'Fiat', 'Palio', 2013, '1.0', 167899),
  (53, 'VGG7G36', 'Chevrolet', 'Onix', 2017, '1.0', 122735),
  (54, 'AZJ6I12', 'Chevrolet', 'Cruze', 2020, '1.4 T', 90349),
  (54, 'GDP2706', 'Fiat', 'Argo', 2024, '1.3', 34097),
  (55, 'SDL2G13', 'Volkswagen', 'Saveiro', 2008, '1.6', 262908),
  (56, 'OQW4J88', 'Toyota', 'Etios', 2024, '1.5', 32320),
  (57, 'NYP1123', 'Toyota', 'Corolla', 2010, '2.0', 205427),
  (58, 'UKX5314', 'Toyota', 'Etios', 2013, '1.5', 161581),
  (59, 'BBC0E84', 'Volkswagen', 'Saveiro', 2023, '1.6', 33564),
  (60, 'TOG7384', 'Chevrolet', 'Celta', 2020, '1.0', 66747),
  (60, 'CMS3509', 'Chevrolet', 'Celta', 2021, '1.0', 77706),
  (61, 'SQV0I79', 'Volkswagen', 'Polo', 2025, '1.0 TSI', 18922),
  (62, 'JTM2F38', 'Honda', 'Fit', 2023, '1.5', 44742),
  (63, 'ODY4782', 'Honda', 'Fit', 2008, '1.5', 171084),
  (64, 'ZTL0138', 'Ford', 'Fiesta', 2025, '1.6', 13684),
  (65, 'AEL1F72', 'Renault', 'Logan', 2023, '1.6', 35627),
  (66, 'RNK5G14', 'Fiat', 'Palio', 2023, '1.0', 39724),
  (66, 'ZON3C61', 'Volkswagen', 'Saveiro', 2023, '1.6', 34394),
  (67, 'VSP1850', 'Fiat', 'Palio', 2016, '1.0', 160430),
  (68, 'JSF7D82', 'Toyota', 'Etios', 2012, '1.5', 175760),
  (69, 'JKX9I86', 'Ford', 'Ka', 2025, '1.0', 17194),
  (70, 'EEF0080', 'Hyundai', 'HB20', 2016, '1.6', 151662),
  (71, 'ONB3I36', 'Volkswagen', 'Voyage', 2018, '1.6', 85715),
  (72, 'EZC8224', 'Hyundai', 'HB20', 2010, '1.6', 256573),
  (72, 'FCA8I14', 'Chevrolet', 'Celta', 2024, '1.0', 23213),
  (73, 'JPQ5425', 'Volkswagen', 'Voyage', 2018, '1.6', 129042),
  (74, 'WTP5457', 'Fiat', 'Palio', 2019, '1.4', 69763),
  (75, 'CBW0C64', 'Ford', 'EcoSport', 2025, '1.6', 19949),
  (75, 'BTX0G55', 'Fiat', 'Palio', 2012, '1.4', 151503),
  (76, 'EHP2368', 'Volkswagen', 'Polo', 2023, '1.0 TSI', 42049),
  (77, 'LHG6C14', 'Toyota', 'Corolla', 2013, '2.0', 123064),
  (78, 'OMZ0A11', 'Volkswagen', 'Polo', 2017, '1.0 TSI', 98390),
  (78, 'WMM1318', 'Fiat', 'Strada', 2013, '1.3', 187632),
  (79, 'UYH8E16', 'Toyota', 'Corolla', 2018, '2.0', 100096),
  (80, 'CIN7153', 'Fiat', 'Uno', 2023, '1.0', 44887),
  (81, 'ISC8G12', 'Fiat', 'Mobi', 2021, '1.0', 62904),
  (82, 'BGF8096', 'Volkswagen', 'Polo', 2020, '1.0 TSI', 89359),
  (83, 'MZX3G74', 'Toyota', 'Corolla', 2012, '2.0', 181995),
  (84, 'BFS9J23', 'Hyundai', 'HB20', 2018, '1.6', 84207);
INSERT INTO veiculo (id_cliente, placa, marca, modelo, ano, motor, km_atual) VALUES
  (84, 'HDZ5H60', 'Volkswagen', 'Saveiro', 2013, '1.6', 133900),
  (85, 'HWZ7094', 'Fiat', 'Mobi', 2011, '1.0', 142525),
  (86, 'TKL1E83', 'Fiat', 'Argo', 2018, '1.0', 85120),
  (87, 'PWE5733', 'Fiat', 'Strada', 2011, '1.3', 189635),
  (88, 'FDN1D23', 'Fiat', 'Argo', 2018, '1.0', 102600),
  (89, 'IJL8180', 'Honda', 'Fit', 2011, '1.5', 190046),
  (90, 'PBQ4G03', 'Toyota', 'Corolla', 2010, '2.0', 230268),
  (90, 'JTC9D00', 'Honda', 'Fit', 2017, '1.5', 106256),
  (91, 'PRI9883', 'Fiat', 'Uno', 2010, '1.0', 255681),
  (92, 'YJX1867', 'Fiat', 'Palio', 2017, '1.0', 143801),
  (93, 'CSD6840', 'Chevrolet', 'Prisma', 2015, '1.4', 132584),
  (94, 'MQI0E25', 'Fiat', 'Palio', 2009, '1.4', 189820),
  (95, 'DLE9J60', 'Fiat', 'Palio', 2022, '1.4', 50853),
  (96, 'MKM0E07', 'Fiat', 'Uno', 2018, '1.0', 89004),
  (96, 'KHB0596', 'Fiat', 'Argo', 2008, '1.0', 250575),
  (97, 'PTD1A57', 'Honda', 'Civic', 2011, '2.0', 179460),
  (98, 'FEJ9073', 'Ford', 'Fiesta', 2011, '1.6', 233573),
  (99, 'ESW1H24', 'Renault', 'Sandero', 2009, '1.0', 195807),
  (100, 'NIX0I80', 'Volkswagen', 'Fox', 2008, '1.0', 165930),
  (101, 'UGM6B50', 'Ford', 'EcoSport', 2021, '1.6', 73988),
  (102, 'TXZ5289', 'Volkswagen', 'Fox', 2013, '1.6', 207526),
  (102, 'LUD9435', 'Toyota', 'Etios', 2023, '1.5', 45871),
  (103, 'XBP2489', 'Volkswagen', 'Saveiro', 2015, '1.6', 111403),
  (104, 'VBT0B96', 'Ford', 'Fiesta', 2018, '1.6', 127723),
  (105, 'ISH2079', 'Fiat', 'Palio', 2014, '1.4', 139486),
  (105, 'OGS4I02', 'Chevrolet', 'Onix', 2009, '1.4', 226051),
  (106, 'QDK6834', 'Fiat', 'Argo', 2017, '1.0', 139542),
  (107, 'XBP1021', 'Fiat', 'Palio', 2014, '1.0', 183394),
  (108, 'NUX0930', 'Hyundai', 'HB20', 2008, '1.6', 247826),
  (108, 'JNE8343', 'Volkswagen', 'Voyage', 2017, '1.6', 147518),
  (109, 'LDN6D58', 'Fiat', 'Mobi', 2011, '1.0', 162834),
  (110, 'NKC0428', 'Chevrolet', 'Onix', 2008, '1.0', 215907);

INSERT INTO servico (nome_servico, descricao, valor_base, ativo) VALUES
  ('Troca de óleo e filtro', 'Óleo do motor e filtro de óleo', 120.00, 1),
  ('Revisão completa', 'Revisão com troca de filtros, óleo e checklist de 40 itens', 350.00, 1),
  ('Troca de correia dentada', 'Substituição do kit de correia dentada e tensor', 450.00, 1),
  ('Troca de pastilhas de freio', 'Pastilhas do eixo dianteiro', 180.00, 1),
  ('Troca de discos de freio', 'Discos do eixo dianteiro', 220.00, 1),
  ('Alinhamento e balanceamento', 'Alinhamento 3D e balanceamento das 4 rodas', 150.00, 1),
  ('Troca de amortecedores dianteiros', 'Par de amortecedores dianteiros', 300.00, 1),
  ('Troca de embreagem', 'Kit de embreagem (platô, disco e rolamento)', 650.00, 1),
  ('Diagnóstico eletrônico', 'Leitura de falhas com scanner', 120.00, 1),
  ('Limpeza de bicos injetores', 'Limpeza por ultrassom', 180.00, 1),
  ('Troca de velas', 'Jogo de velas de ignição', 100.00, 1),
  ('Troca de bateria', 'Substituição e teste do sistema de carga', 60.00, 1),
  ('Higienização do ar-condicionado', 'Higienização e troca do filtro de cabine', 150.00, 1),
  ('Troca de fluido de freio', 'Sangria e troca do fluido', 120.00, 1),
  ('Troca de líquido de arrefecimento', 'Drenagem e reposição do aditivo', 130.00, 1),
  ('Troca de bomba d''água', 'Substituição da bomba d''água', 280.00, 1),
  ('Troca de bieletas', 'Par de bieletas da suspensão dianteira', 120.00, 1),
  ('Troca de terminais de direção', 'Par de terminais + alinhamento', 140.00, 1),
  ('Reparo elétrico', 'Hora técnica de elétrica', 150.00, 1),
  ('Troca de correia do alternador', 'Correia poly-V do alternador', 90.00, 1);

INSERT INTO peca (nome_peca, codigo_fabricante, unidade, valor_venda, estoque_minimo, ativo) VALUES
  ('Óleo de motor 5W30 sintético', 'OL-5W30-1L', 'litro', 48.00, 40, 1),
  ('Filtro de óleo', 'FO-0101', 'un', 38.00, 15, 1),
  ('Filtro de ar do motor', 'FA-0202', 'un', 55.00, 8, 1),
  ('Filtro de combustível', 'FC-0303', 'un', 62.00, 6, 1),
  ('Filtro de ar-condicionado (cabine)', 'FCB-0404', 'un', 58.00, 6, 1),
  ('Kit correia dentada + tensor', 'KCD-1500', 'kit', 420.00, 3, 1),
  ('Jogo de pastilhas de freio dianteiro', 'PF-2201', 'jogo', 160.00, 5, 1),
  ('Disco de freio dianteiro', 'DF-2301', 'un', 190.00, 4, 1),
  ('Amortecedor dianteiro', 'AM-3101', 'un', 380.00, 4, 1),
  ('Kit embreagem', 'KE-4100', 'kit', 890.00, 2, 1),
  ('Vela de ignição', 'VI-5101', 'un', 32.00, 16, 1),
  ('Bateria 60Ah', 'BT-60AH', 'un', 520.00, 2, 1),
  ('Fluido de freio DOT4 500ml', 'FF-DOT4', 'un', 45.00, 6, 1),
  ('Aditivo de radiador 1L', 'AR-1000', 'litro', 35.00, 8, 1),
  ('Bomba d''água', 'BA-6101', 'un', 310.00, 2, 1),
  ('Bieleta da suspensão', 'BL-3201', 'un', 95.00, 4, 1),
  ('Terminal de direção', 'TD-3301', 'un', 110.00, 4, 1),
  ('Lâmpada farol H4', 'LP-H4', 'un', 28.00, 10, 1),
  ('Palheta do limpador', 'PL-0500', 'jogo', 70.00, 4, 1),
  ('Correia do alternador', 'CA-6PK', 'un', 85.00, 3, 1);

INSERT INTO fornecedor (razao_social, cnpj, telefone, email, ativo) VALUES
  ('Auto Peças Carmo Ltda.', '12.345.678/0001-90', '(11) 2522-1000', 'vendas1@fornecedor.exemplo', 1),
  ('Distribuidora Leste Autopeças Ltda.', '23.456.789/0001-01', '(11) 2041-2200', 'vendas2@fornecedor.exemplo', 1),
  ('Itaquera Rolamentos e Peças Ltda.', '34.567.890/0001-12', '(11) 2286-3300', 'vendas3@fornecedor.exemplo', 1),
  ('Lubrificantes Zona Leste Ltda.', '45.678.901/0001-23', '(11) 2944-4400', 'vendas4@fornecedor.exemplo', 1),
  ('Freios & Cia Comércio de Peças Ltda.', '56.789.012/0001-34', '(11) 2721-5500', 'vendas5@fornecedor.exemplo', 1),
  ('Baterias Penha Comércio Ltda.', '67.890.123/0001-45', '(11) 2958-6600', 'vendas6@fornecedor.exemplo', 1);

INSERT INTO ordem_servico (numero_os, id_veiculo, id_atendente, id_mecanico, km_entrada, problema_relatado, data_entrada, data_previsao, data_saida, status, cliente_avisado, garantia_ate, numero_nota_fiscal, observacoes) VALUES
  (25101, 50, 4, 9, 17084, 'Carro puxando para o lado', '2026-09-01 14:20:00', '2026-09-03', '2026-09-03 17:20:00', 'entregue', 1, '2026-12-02', 'NFSe-25101', NULL),
  (25102, 107, 4, 5, 228901, 'Troca de óleo vencida pela km', '2026-09-01 12:40:00', '2026-09-02', '2026-09-04 13:40:00', 'entregue', 1, '2026-12-03', 'NFSe-25102', NULL),
  (25103, 44, 4, 9, 133087, 'Barulho ao frear', '2026-09-01 13:50:00', '2026-09-02', '2026-09-01 14:50:00', 'entregue', 1, '2026-11-30', 'NFSe-25103', NULL),
  (25104, 90, 4, 7, 150847, 'Barulho ao frear', '2026-09-01 15:30:00', '2026-09-04', '2026-09-04 19:30:00', 'entregue', 1, '2026-12-03', 'NFSe-25104', NULL),
  (25105, 9, 4, 9, 217050, 'Revisão dos 40 mil km', '2026-09-01 14:10:00', '2026-09-03', '2026-09-02 19:10:00', 'entregue', 1, '2026-12-01', 'NFSe-25105', NULL),
  (25106, 117, 2, 6, 231758, 'Revisão dos 40 mil km', '2026-09-01 13:00:00', '2026-09-03', '2026-09-02 14:00:00', 'entregue', 1, '2026-12-01', 'NFSe-25106', NULL),
  (25107, 131, 4, 9, 162834, 'Motor esquentando', '2026-09-02 14:20:00', '2026-09-05', '2026-09-02 19:20:00', 'entregue', 1, '2026-12-01', 'NFSe-25107', NULL),
  (25108, 84, 4, 6, 83159, 'Revisão dos 40 mil km', '2026-09-02 08:00:00', '2026-09-05', '2026-09-03 12:00:00', 'entregue', 1, '2026-12-02', 'NFSe-25108', 'Retorno em garantia em 08/09/2026: refeito o serviço ''Revisão completa'' sem custo; data de entrada mantida (RN05).'),
  (25109, 5, 4, 6, 30995, 'Barulho na suspensão em lombadas', '2026-09-02 16:30:00', '2026-09-03', '2026-09-03 19:30:00', 'entregue', 1, '2026-12-02', 'NFSe-25109', NULL),
  (25110, 73, 4, 5, 14812, 'Revisão dos 40 mil km', '2026-09-02 09:30:00', '2026-09-04', '2026-09-03 12:30:00', 'entregue', 1, '2026-12-02', 'NFSe-25110', 'Retorno em garantia em 11/09/2026: refeito o serviço ''Revisão completa'' sem custo; data de entrada mantida (RN05).'),
  (25111, 119, 4, 8, 165365, 'Carro não dá partida', '2026-09-02 16:40:00', '2026-09-03', '2026-09-02 20:40:00', 'entregue', 1, '2026-12-01', 'NFSe-25111', 'Retorno em garantia em 11/09/2026: refeito o serviço ''Troca de bateria'' sem custo; data de entrada mantida (RN05).'),
  (25112, 7, 4, 9, 70391, 'Carro puxando para o lado', '2026-09-02 14:40:00', '2026-09-04', '2026-09-02 17:40:00', 'entregue', 1, '2026-12-01', 'NFSe-25112', NULL),
  (25113, 79, 4, 5, 34394, 'Barulho ao frear', '2026-09-02 14:20:00', '2026-09-03', '2026-09-03 19:20:00', 'entregue', 1, '2026-12-02', 'NFSe-25113', NULL),
  (25114, 6, 4, 7, 146055, 'Luz de injeção acesa no painel', '2026-09-03 16:30:00', '2026-09-06', '2026-09-04 17:30:00', 'entregue', 1, '2026-12-03', 'NFSe-25114', NULL),
  (25115, 9, 4, 6, 218220, 'Vazamento de água no motor', '2026-09-03 11:40:00', '2026-09-05', '2026-09-06 13:40:00', 'entregue', 1, '2026-12-05', 'NFSe-25115', NULL),
  (25116, 44, 4, 5, 135514, 'Barulho ao frear', '2026-09-03 11:50:00', '2026-09-04', '2026-09-04 12:50:00', 'entregue', 1, '2026-12-03', 'NFSe-25116', NULL),
  (25117, 127, 4, 5, 138249, 'Troca de óleo vencida pela km', '2026-09-03 13:00:00', '2026-09-04', '2026-09-05 14:00:00', 'entregue', 1, '2026-12-04', 'NFSe-25117', NULL),
  (25118, 89, 4, 7, 17727, 'Motor esquentando', '2026-09-03 09:20:00', '2026-09-04', '2026-09-03 11:20:00', 'entregue', 1, '2026-12-02', 'NFSe-25118', 'Retorno em garantia em 10/09/2026: refeito o serviço ''Troca de líquido de arrefecimento'' sem custo; data de entrada mantida (RN05).'),
  (25119, 46, 4, 7, 120149, 'Troca de óleo vencida pela km', '2026-09-03 15:40:00', '2026-09-05', '2026-09-04 19:40:00', 'entregue', 1, '2026-12-03', 'NFSe-25119', NULL),
  (25120, 129, 2, 7, 244029, 'Estalo na suspensão', '2026-09-04 10:00:00', '2026-09-06', '2026-09-05 12:00:00', 'entregue', 1, '2026-12-04', 'NFSe-25120', NULL),
  (25121, 84, 4, 6, 83471, 'Revisão dos 40 mil km', '2026-09-04 13:30:00', '2026-09-05', '2026-09-05 15:30:00', 'entregue', 1, '2026-12-04', 'NFSe-25121', NULL),
  (25122, 88, 2, 6, 68095, 'Troca de óleo vencida pela km', '2026-09-04 13:30:00', '2026-09-07', '2026-09-05 15:30:00', 'entregue', 1, '2026-12-04', 'NFSe-25122', NULL),
  (25123, 14, 4, 9, 216727, 'Revisão dos 40 mil km', '2026-09-04 16:20:00', '2026-09-05', '2026-09-05 18:20:00', 'entregue', 1, '2026-12-04', 'NFSe-25123', NULL),
  (25124, 80, 4, 6, 158143, 'Correia dentada no prazo de troca', '2026-09-04 08:40:00', '2026-09-05', '2026-09-07 11:40:00', 'entregue', 1, '2026-12-06', 'NFSe-25124', NULL),
  (25125, 73, 4, 5, 16667, 'Barulho ao frear', '2026-09-04 09:40:00', '2026-09-07', '2026-09-04 13:40:00', 'entregue', 1, '2026-12-03', 'NFSe-25125', NULL),
  (25126, 111, 4, NULL, 130168, 'Vazamento de água no motor', '2026-09-05 13:00:00', '2026-09-07', NULL, 'cancelada', 0, NULL, NULL, NULL),
  (25127, 115, 4, 6, 248343, 'Cheiro ruim no ar-condicionado', '2026-09-05 14:20:00', '2026-09-06', '2026-09-07 17:20:00', 'entregue', 1, '2026-12-06', 'NFSe-25127', NULL),
  (25128, 3, 2, 5, 194734, 'Farol queimado e pane elétrica', '2026-09-05 13:00:00', '2026-09-07', '2026-09-05 14:00:00', 'entregue', 1, '2026-12-04', 'NFSe-25128', NULL),
  (25129, 64, 4, 7, 90349, 'Farol queimado e pane elétrica', '2026-09-07 14:50:00', '2026-09-10', '2026-09-07 18:50:00', 'entregue', 1, '2026-12-06', 'NFSe-25129', NULL),
  (25130, 97, 4, 8, 62391, 'Troca de óleo vencida pela km', '2026-09-07 12:00:00', '2026-09-10', '2026-09-10 17:00:00', 'entregue', 1, '2026-12-09', 'NFSe-25130', NULL),
  (25131, 20, 4, 7, 56061, 'Barulho ao frear', '2026-09-07 11:20:00', '2026-09-08', '2026-09-07 13:20:00', 'entregue', 1, '2026-12-06', 'NFSe-25131', NULL),
  (25132, 127, 4, 5, 139542, 'Barulho ao frear', '2026-09-07 12:00:00', '2026-09-08', '2026-09-08 13:00:00', 'entregue', 1, '2026-12-07', 'NFSe-25132', NULL),
  (25133, 109, 4, 6, 255681, 'Troca de óleo vencida pela km', '2026-09-07 09:50:00', '2026-09-10', '2026-09-07 14:50:00', 'entregue', 1, '2026-12-06', 'NFSe-25133', NULL),
  (25134, 81, 4, 8, 173667, 'Carro puxando para o lado', '2026-09-07 09:50:00', '2026-09-10', '2026-09-07 10:50:00', 'entregue', 1, '2026-12-06', 'NFSe-25134', NULL),
  (25135, 90, 4, 7, 151503, 'Carro puxando para o lado', '2026-09-08 13:40:00', '2026-09-11', '2026-09-09 18:40:00', 'entregue', 1, '2026-12-08', 'NFSe-25135', NULL),
  (25136, 130, 4, 9, 146486, 'Cheiro ruim no ar-condicionado', '2026-09-08 10:20:00', '2026-09-11', '2026-09-09 13:20:00', 'entregue', 1, '2026-12-08', 'NFSe-25136', NULL),
  (25137, 21, 2, 5, 93554, 'Farol queimado e pane elétrica', '2026-09-08 16:50:00', '2026-09-10', '2026-09-09 19:50:00', 'entregue', 1, '2026-12-08', 'NFSe-25137', NULL),
  (25138, 2, 4, 8, 175072, 'Motor esquentando', '2026-09-08 14:10:00', '2026-09-09', '2026-09-09 17:10:00', 'entregue', 1, '2026-12-08', 'NFSe-25138', NULL),
  (25139, 98, 4, 9, 89359, 'Troca de óleo vencida pela km', '2026-09-08 12:50:00', '2026-09-11', '2026-09-09 14:50:00', 'entregue', 1, '2026-12-08', 'NFSe-25139', NULL),
  (25140, 40, 4, 5, 214789, 'Troca de óleo vencida pela km', '2026-09-08 08:50:00', '2026-09-11', '2026-09-11 11:50:00', 'entregue', 1, '2026-12-10', 'NFSe-25140', NULL),
  (25141, 119, 4, 7, 165930, 'Cheiro ruim no ar-condicionado', '2026-09-08 10:50:00', '2026-09-11', '2026-09-10 11:50:00', 'entregue', 1, '2026-12-09', 'NFSe-25141', NULL),
  (25142, 108, 4, 9, 103347, 'Revisão dos 40 mil km', '2026-09-09 14:50:00', '2026-09-10', '2026-09-10 17:50:00', 'entregue', 1, '2026-12-09', 'NFSe-25142', NULL),
  (25143, 100, 4, 8, 79844, 'Carro puxando para o lado', '2026-09-09 15:40:00', '2026-09-11', '2026-09-10 19:40:00', 'entregue', 1, '2026-12-09', 'NFSe-25143', NULL),
  (25144, 81, 4, 9, 174577, 'Troca de óleo vencida pela km', '2026-09-09 10:40:00', '2026-09-10', '2026-09-10 11:40:00', 'entregue', 1, '2026-12-09', 'NFSe-25144', NULL),
  (25145, 130, 4, 8, 147518, 'Correia dentada no prazo de troca', '2026-09-09 10:30:00', '2026-09-11', '2026-09-12 13:30:00', 'entregue', 1, '2026-12-11', 'NFSe-25145', NULL),
  (25146, 25, 4, 5, 95752, 'Carro puxando para o lado', '2026-09-09 15:20:00', '2026-09-12', '2026-09-09 18:20:00', 'entregue', 1, '2026-12-08', 'NFSe-25146', NULL),
  (25147, 67, 4, 8, 27422, 'Troca de óleo vencida pela km', '2026-09-10 08:00:00', '2026-09-13', '2026-09-10 13:00:00', 'entregue', 1, '2026-12-09', 'NFSe-25147', NULL),
  (25148, 83, 4, 8, 151662, 'Luz de injeção acesa no painel', '2026-09-10 16:10:00', '2026-09-13', '2026-09-11 19:10:00', 'entregue', 1, '2026-12-10', 'NFSe-25148', NULL),
  (25149, 72, 4, 8, 75815, 'Estalo na suspensão', '2026-09-10 14:00:00', '2026-09-13', '2026-09-11 18:00:00', 'entregue', 1, '2026-12-10', 'NFSe-25149', NULL),
  (25150, 39, 4, 6, 257119, 'Barulho ao frear', '2026-09-10 11:10:00', '2026-09-12', '2026-09-13 15:10:00', 'entregue', 1, '2026-12-12', 'NFSe-25150', NULL);
INSERT INTO ordem_servico (numero_os, id_veiculo, id_atendente, id_mecanico, km_entrada, problema_relatado, data_entrada, data_previsao, data_saida, status, cliente_avisado, garantia_ate, numero_nota_fiscal, observacoes) VALUES
  (25151, 59, 4, 9, 82454, 'Troca de óleo vencida pela km', '2026-09-10 13:20:00', '2026-09-11', '2026-09-13 17:20:00', 'entregue', 1, '2026-12-12', 'NFSe-25151', NULL),
  (25152, 95, 4, 8, 100096, 'Troca de óleo vencida pela km', '2026-09-10 13:50:00', '2026-09-11', '2026-09-11 16:50:00', 'entregue', 1, '2026-12-10', 'NFSe-25152', NULL),
  (25153, 51, 4, 8, 38556, 'Carro puxando para o lado', '2026-09-10 11:50:00', '2026-09-12', '2026-09-11 16:50:00', 'entregue', 1, '2026-12-10', 'NFSe-25153', NULL),
  (25154, 17, 4, 5, 64905, 'Barulho na suspensão em lombadas', '2026-09-11 09:50:00', '2026-09-12', '2026-09-14 13:50:00', 'entregue', 1, '2026-12-13', 'NFSe-25154', NULL),
  (25155, 48, 4, 8, 15478, 'Revisão dos 40 mil km', '2026-09-11 14:30:00', '2026-09-12', '2026-09-12 15:30:00', 'entregue', 1, '2026-12-11', 'NFSe-25155', NULL),
  (25156, 132, 4, 6, 213773, 'Cheiro ruim no ar-condicionado', '2026-09-11 15:10:00', '2026-09-12', '2026-09-12 16:10:00', 'entregue', 1, '2026-12-11', 'NFSe-25156', NULL),
  (25157, 111, 4, NULL, 132584, 'Barulho ao frear', '2026-09-11 14:20:00', '2026-09-13', NULL, 'cancelada', 0, NULL, NULL, NULL),
  (25158, 65, 4, 9, 34097, 'Chiado no motor ao ligar', '2026-09-11 15:30:00', '2026-09-13', '2026-09-13 20:30:00', 'entregue', 1, '2026-12-12', 'NFSe-25158', NULL),
  (25159, 120, 4, 6, 73988, 'Troca de óleo vencida pela km', '2026-09-12 08:50:00', '2026-09-15', '2026-09-14 09:50:00', 'entregue', 1, '2026-12-13', 'NFSe-25159', NULL),
  (25160, 80, 4, 6, 160430, 'Troca de óleo vencida pela km', '2026-09-12 10:00:00', '2026-09-15', '2026-09-13 14:00:00', 'entregue', 1, '2026-12-12', 'NFSe-25160', NULL),
  (25161, 81, 4, 9, 175760, 'Farol queimado e pane elétrica', '2026-09-12 16:50:00', '2026-09-15', '2026-09-12 17:50:00', 'entregue', 1, '2026-12-11', 'NFSe-25161', NULL),
  (25162, 100, 4, 5, 82199, 'Carro não dá partida', '2026-09-14 13:20:00', '2026-09-17', '2026-09-14 17:20:00', 'entregue', 1, '2026-12-13', 'NFSe-25162', NULL),
  (25163, 2, 4, 6, 177475, 'Correia dentada no prazo de troca', '2026-09-14 10:40:00', '2026-09-16', '2026-09-14 15:40:00', 'entregue', 1, '2026-12-13', 'NFSe-25163', NULL),
  (25164, 60, 4, 8, 72744, 'Troca de óleo vencida pela km', '2026-09-14 08:30:00', '2026-09-17', '2026-09-16 09:30:00', 'entregue', 1, '2026-12-15', 'NFSe-25164', NULL),
  (25165, 84, 4, 5, 85715, 'Barulho ao frear', '2026-09-14 09:00:00', '2026-09-16', '2026-09-15 14:00:00', 'entregue', 1, '2026-12-14', 'NFSe-25165', NULL),
  (25166, 89, 2, 8, 18564, 'Pedal de freio baixo', '2026-09-14 15:40:00', '2026-09-17', '2026-09-16 17:40:00', 'entregue', 1, '2026-12-15', 'NFSe-25166', NULL),
  (25167, 28, 4, 8, 87955, 'Troca de óleo vencida pela km', '2026-09-14 12:30:00', '2026-09-15', '2026-09-14 14:30:00', 'entregue', 1, '2026-12-13', 'NFSe-25167', NULL),
  (25168, 17, 2, 5, 66756, 'Troca de óleo vencida pela km', '2026-09-15 10:10:00', '2026-09-16', '2026-09-18 13:10:00', 'entregue', 1, '2026-12-17', 'NFSe-25168', NULL),
  (25169, 59, 4, 8, 84839, 'Farol queimado e pane elétrica', '2026-09-15 10:50:00', '2026-09-16', '2026-09-18 11:50:00', 'entregue', 1, '2026-12-17', 'NFSe-25169', NULL),
  (25170, 116, 4, 5, 179460, 'Troca de óleo vencida pela km', '2026-09-15 14:20:00', '2026-09-18', '2026-09-17 15:20:00', 'entregue', 1, '2026-12-16', 'NFSe-25170', NULL),
  (25171, 7, 2, 7, 72730, 'Troca de óleo vencida pela km', '2026-09-15 11:10:00', '2026-09-17', '2026-09-15 15:10:00', 'entregue', 1, '2026-12-14', 'NFSe-25171', NULL),
  (25172, 59, 4, 9, 85682, 'Carro não dá partida', '2026-09-15 09:50:00', '2026-09-16', '2026-09-16 12:50:00', 'entregue', 1, '2026-12-15', 'NFSe-25172', 'Retorno em garantia em 25/09/2026: refeito o serviço ''Troca de bateria'' sem custo; data de entrada mantida (RN05).'),
  (25173, 55, 4, NULL, 83046, 'Luz de injeção acesa no painel', '2026-09-15 13:40:00', '2026-09-17', NULL, 'cancelada', 0, NULL, NULL, NULL),
  (25174, 85, 4, 7, 256573, 'Barulho ao frear', '2026-09-16 09:00:00', '2026-09-17', '2026-09-18 12:00:00', 'entregue', 1, '2026-12-17', 'NFSe-25174', NULL),
  (25175, 91, 4, 6, 40259, 'Revisão dos 40 mil km', '2026-09-16 09:20:00', '2026-09-19', '2026-09-18 14:20:00', 'entregue', 1, '2026-12-17', 'NFSe-25175', NULL),
  (25176, 32, 4, 8, 77592, 'Estalo na suspensão', '2026-09-16 13:10:00', '2026-09-19', '2026-09-17 18:10:00', 'entregue', 1, '2026-12-16', 'NFSe-25176', 'Retorno em garantia em 22/09/2026: refeito o serviço ''Troca de bieletas'' sem custo; data de entrada mantida (RN05).'),
  (25177, 87, 4, 8, 129042, 'Troca de óleo vencida pela km', '2026-09-16 11:30:00', '2026-09-18', '2026-09-16 16:30:00', 'entregue', 1, '2026-12-15', 'NFSe-25177', NULL),
  (25178, 35, 2, 7, 160221, 'Luz de injeção acesa no painel', '2026-09-16 08:20:00', '2026-09-18', '2026-09-18 11:20:00', 'entregue', 1, '2026-12-17', 'NFSe-25178', NULL),
  (25179, 16, 4, 5, 194760, 'Carro não dá partida', '2026-09-16 14:50:00', '2026-09-19', '2026-09-16 19:50:00', 'entregue', 1, '2026-12-15', 'NFSe-25179', NULL),
  (25180, 94, 4, 5, 185607, 'Pedal de freio baixo', '2026-09-16 14:50:00', '2026-09-19', '2026-09-17 19:50:00', 'entregue', 1, '2026-12-16', 'NFSe-25180', NULL),
  (25181, 63, 4, NULL, 122735, 'Barulho ao frear', '2026-09-17 10:20:00', '2026-09-19', NULL, 'cancelada', 0, NULL, NULL, NULL),
  (25182, 128, 4, 7, 183394, 'Volante treme ao frear', '2026-09-17 09:00:00', '2026-09-19', '2026-09-18 14:00:00', 'entregue', 1, '2026-12-17', 'NFSe-25182', NULL),
  (25183, 60, 2, 7, 73717, 'Motor esquentando', '2026-09-17 13:30:00', '2026-09-18', '2026-09-17 14:30:00', 'entregue', 1, '2026-12-16', 'NFSe-25183', NULL),
  (25184, 94, 4, 5, 187632, 'Barulho na suspensão em lombadas', '2026-09-17 14:00:00', '2026-09-18', '2026-09-17 18:00:00', 'entregue', 1, '2026-12-16', 'NFSe-25184', NULL),
  (25185, 108, 4, NULL, 105066, 'Carro puxando para o lado', '2026-09-17 09:00:00', '2026-09-20', NULL, 'cancelada', 0, NULL, NULL, NULL),
  (25186, 101, 4, 8, 133900, 'Troca de óleo vencida pela km', '2026-09-18 10:20:00', '2026-09-19', '2026-09-18 13:20:00', 'entregue', 1, '2026-12-17', 'NFSe-25186', NULL),
  (25187, 55, 4, 6, 83879, 'Carro puxando para o lado', '2026-09-18 11:50:00', '2026-09-19', '2026-09-20 12:50:00', 'entregue', 1, '2026-12-19', 'NFSe-25187', NULL),
  (25188, 67, 4, 8, 29880, 'Carro falhando na partida', '2026-09-18 11:40:00', '2026-09-20', '2026-09-19 12:40:00', 'entregue', 1, '2026-12-18', 'NFSe-25188', NULL),
  (25189, 36, 4, 7, 249604, 'Correia dentada no prazo de troca', '2026-09-18 08:20:00', '2026-09-21', '2026-09-19 09:20:00', 'entregue', 1, '2026-12-18', 'NFSe-25189', NULL),
  (25190, 55, 2, 9, 85323, 'Luz de injeção acesa no painel', '2026-09-18 10:40:00', '2026-09-21', '2026-09-19 11:40:00', 'entregue', 1, '2026-12-18', 'NFSe-25190', NULL),
  (25191, 8, 2, 5, 145534, 'Barulho ao frear', '2026-09-18 15:50:00', '2026-09-19', '2026-09-18 19:50:00', 'entregue', 1, '2026-12-17', 'NFSe-25191', NULL),
  (25192, 5, 4, 9, 33002, 'Luz de injeção acesa no painel', '2026-09-19 09:00:00', '2026-09-21', '2026-09-21 12:00:00', 'entregue', 1, '2026-12-20', 'NFSe-25192', NULL),
  (25193, 19, 4, 5, 85177, 'Troca de óleo vencida pela km', '2026-09-19 09:30:00', '2026-09-21', '2026-09-19 10:30:00', 'entregue', 1, '2026-12-18', 'NFSe-25193', NULL),
  (25194, 126, 4, 5, 226051, 'Troca de óleo vencida pela km', '2026-09-19 09:40:00', '2026-09-22', '2026-09-22 12:40:00', 'entregue', 1, '2026-12-21', 'NFSe-25194', NULL),
  (25195, 99, 4, 8, 181995, 'Farol queimado e pane elétrica', '2026-09-21 11:20:00', '2026-09-22', '2026-09-24 15:20:00', 'entregue', 1, '2026-12-23', 'NFSe-25195', NULL),
  (25196, 107, 4, 5, 229420, 'Troca de óleo vencida pela km', '2026-09-21 13:50:00', '2026-09-24', '2026-09-22 14:50:00', 'entregue', 1, '2026-12-21', 'NFSe-25196', NULL),
  (25197, 91, 4, 7, 41250, 'Embreagem patinando', '2026-09-21 08:40:00', '2026-09-24', '2026-09-22 13:40:00', 'entregue', 1, '2026-12-21', 'NFSe-25197', NULL),
  (25198, 55, 4, 9, 87530, 'Motor falhando em marcha lenta', '2026-09-21 12:10:00', '2026-09-22', '2026-09-21 14:10:00', 'entregue', 1, '2026-12-20', 'NFSe-25198', NULL),
  (25199, 57, 2, 8, 163216, 'Estalo na suspensão', '2026-09-21 08:30:00', '2026-09-22', '2026-09-24 09:30:00', 'entregue', 1, '2026-12-23', 'NFSe-25199', NULL),
  (25200, 96, 4, 8, 44887, 'Troca de óleo vencida pela km', '2026-09-21 10:00:00', '2026-09-23', '2026-09-22 11:00:00', 'entregue', 1, '2026-12-21', 'NFSe-25200', NULL);
INSERT INTO ordem_servico (numero_os, id_veiculo, id_atendente, id_mecanico, km_entrada, problema_relatado, data_entrada, data_previsao, data_saida, status, cliente_avisado, garantia_ate, numero_nota_fiscal, observacoes) VALUES
  (25201, 75, 4, 6, 171084, 'Troca de óleo vencida pela km', '2026-09-22 12:20:00', '2026-09-23', '2026-09-22 13:20:00', 'entregue', 1, '2026-12-21', 'NFSe-25201', NULL),
  (25202, 129, 2, 8, 245646, 'Troca de óleo vencida pela km', '2026-09-22 13:40:00', '2026-09-24', '2026-09-22 14:40:00', 'entregue', 1, '2026-12-21', 'NFSe-25202', NULL),
  (25203, 8, 4, 6, 147752, 'Revisão dos 40 mil km', '2026-09-22 08:20:00', '2026-09-25', '2026-09-23 13:20:00', 'entregue', 1, '2026-12-22', 'NFSe-25203', NULL),
  (25204, 117, 4, 6, 233573, 'Luz de injeção acesa no painel', '2026-09-22 15:30:00', '2026-09-24', '2026-09-24 18:30:00', 'entregue', 1, '2026-12-23', 'NFSe-25204', NULL),
  (25205, 36, 4, 8, 250409, 'Luz de injeção acesa no painel', '2026-09-22 13:40:00', '2026-09-25', '2026-09-22 15:40:00', 'entregue', 1, '2026-12-21', 'NFSe-25205', NULL),
  (25206, 36, 4, 8, 252077, 'Motor esquentando', '2026-09-22 11:10:00', '2026-09-23', '2026-09-25 16:10:00', 'entregue', 1, '2026-12-24', 'NFSe-25206', NULL),
  (25207, 12, 4, 5, 131628, 'Pedal de freio baixo', '2026-09-23 13:10:00', '2026-09-24', '2026-09-26 16:10:00', 'entregue', 1, '2026-12-25', 'NFSe-25207', NULL),
  (25208, 132, 2, 5, 215907, 'Troca de óleo vencida pela km', '2026-09-23 13:40:00', '2026-09-26', '2026-09-24 18:40:00', 'entregue', 1, '2026-12-23', 'NFSe-25208', NULL),
  (25209, 5, 2, 5, 35445, 'Estalo na suspensão', '2026-09-23 08:10:00', '2026-09-26', '2026-09-24 10:10:00', 'entregue', 1, '2026-12-23', 'NFSe-25209', NULL),
  (25210, 69, 4, 9, 161581, 'Troca de óleo vencida pela km', '2026-09-23 08:30:00', '2026-09-25', '2026-09-25 09:30:00', 'entregue', 1, '2026-12-24', 'NFSe-25210', NULL),
  (25211, 67, 4, 8, 32320, 'Barulho ao frear', '2026-09-23 11:00:00', '2026-09-26', '2026-09-24 12:00:00', 'entregue', 1, '2026-12-23', 'NFSe-25211', NULL),
  (25212, 72, 4, 7, 77403, 'Barulho ao frear', '2026-09-23 09:00:00', '2026-09-25', '2026-09-25 12:00:00', 'entregue', 1, '2026-12-24', 'NFSe-25212', NULL),
  (25213, 102, 4, 9, 142525, 'Luz de injeção acesa no painel', '2026-09-24 09:30:00', '2026-09-25', '2026-09-25 12:30:00', 'entregue', 1, '2026-12-24', 'NFSe-25213', NULL),
  (25214, 60, 2, 5, 74816, 'Carro falhando na partida', '2026-09-24 14:50:00', '2026-09-25', '2026-09-26 16:50:00', 'entregue', 1, '2026-12-25', 'NFSe-25214', NULL),
  (25215, 56, 4, 5, 104344, 'Barulho ao frear', '2026-09-24 14:10:00', '2026-09-27', '2026-09-24 17:10:00', 'entregue', 1, '2026-12-23', 'NFSe-25215', NULL),
  (25216, 100, 4, 8, 84207, 'Cheiro ruim no ar-condicionado', '2026-09-24 14:40:00', '2026-09-27', '2026-09-25 15:40:00', 'entregue', 1, '2026-12-24', 'NFSe-25216', NULL),
  (25217, 13, 4, 6, 237624, 'Luz de injeção acesa no painel', '2026-09-24 15:50:00', '2026-09-26', '2026-09-27 18:50:00', 'entregue', 1, '2026-12-26', 'NFSe-25217', NULL),
  (25218, 4, 4, 9, 248619, 'Farol queimado e pane elétrica', '2026-09-24 12:20:00', '2026-09-26', '2026-09-25 13:20:00', 'entregue', 1, '2026-12-24', 'NFSe-25218', NULL),
  (25219, 47, 4, 8, 185949, 'Correia dentada no prazo de troca', '2026-09-25 13:10:00', '2026-09-26', '2026-09-26 17:10:00', 'entregue', 1, '2026-12-25', 'NFSe-25219', NULL),
  (25220, 115, 4, 6, 250575, 'Estalo na suspensão', '2026-09-25 11:20:00', '2026-09-27', '2026-09-25 16:20:00', 'entregue', 1, '2026-12-24', 'NFSe-25220', NULL),
  (25221, 118, 4, 7, 195807, 'Barulho na suspensão em lombadas', '2026-09-25 08:00:00', '2026-09-26', '2026-09-25 12:00:00', 'entregue', 1, '2026-12-24', 'NFSe-25221', NULL),
  (25222, 35, 2, 9, 162685, 'Cheiro ruim no ar-condicionado', '2026-09-25 11:20:00', '2026-09-26', '2026-09-27 13:20:00', 'entregue', 1, '2026-12-26', 'NFSe-25222', NULL),
  (25223, 40, 4, 6, 216606, 'Folga na direção', '2026-09-25 11:50:00', '2026-09-28', '2026-09-26 13:50:00', 'entregue', 1, '2026-12-25', 'NFSe-25223', NULL),
  (25224, 88, 4, 5, 69763, 'Correia dentada no prazo de troca', '2026-09-25 13:40:00', '2026-09-26', '2026-09-26 16:40:00', 'entregue', 1, '2026-12-25', 'NFSe-25224', NULL),
  (25225, 58, 4, 9, 165369, 'Embreagem patinando', '2026-09-26 16:20:00', '2026-09-29', '2026-09-27 21:20:00', 'entregue', 1, '2026-12-26', 'NFSe-25225', NULL),
  (25226, 108, 4, 7, 106256, 'Embreagem patinando', '2026-09-26 12:50:00', '2026-09-27', '2026-09-27 15:50:00', 'entregue', 1, '2026-12-26', 'NFSe-25226', NULL),
  (25227, 72, 4, 7, 77706, 'Vazamento de água no motor', '2026-09-26 16:30:00', '2026-09-28', '2026-09-26 19:30:00', 'entregue', 1, '2026-12-25', 'NFSe-25227', NULL),
  (25228, 97, 4, 5, 62904, 'Revisão dos 40 mil km', '2026-09-28 14:20:00', '2026-09-29', NULL, 'pronta', 1, NULL, NULL, NULL),
  (25229, 129, 4, 9, 247826, 'Luz de injeção acesa no painel', '2026-09-28 09:50:00', '2026-09-30', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25230, 93, 4, 6, 98390, 'Volante treme ao frear', '2026-09-28 11:20:00', '2026-09-29', '2026-09-29 16:20:00', 'entregue', 1, '2026-12-28', 'NFSe-25230', NULL),
  (25231, 8, 4, 6, 149831, 'Vazamento de água no motor', '2026-09-28 08:10:00', '2026-09-30', '2026-09-28 13:10:00', 'entregue', 1, '2026-12-27', 'NFSe-25231', NULL),
  (25232, 48, 4, 5, 16724, 'Barulho na suspensão em lombadas', '2026-09-28 12:10:00', '2026-10-01', NULL, 'pronta', 1, NULL, NULL, NULL),
  (25233, 3, 4, 8, 196388, 'Volante treme ao frear', '2026-09-28 08:20:00', '2026-09-29', '2026-10-01 07:00:00', 'entregue', 1, '2026-12-30', 'NFSe-25233', NULL),
  (25234, 73, 4, 5, 18922, 'Correia dentada no prazo de troca', '2026-09-28 16:30:00', '2026-09-30', NULL, 'pronta', 1, NULL, NULL, NULL),
  (25235, 89, 4, 7, 19157, 'Luz de injeção acesa no painel', '2026-09-29 16:50:00', '2026-10-02', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25236, 54, 4, 5, 195753, 'Correia dentada no prazo de troca', '2026-09-29 15:50:00', '2026-10-02', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25237, 107, 4, 7, 230268, 'Cheiro ruim no ar-condicionado', '2026-09-29 08:20:00', '2026-10-01', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25238, 91, 4, 6, 42049, 'Barulho ao frear', '2026-09-29 15:40:00', '2026-10-01', NULL, 'pronta', 1, NULL, NULL, NULL),
  (25239, 5, 2, 9, 36589, 'Carro puxando para o lado', '2026-09-29 16:20:00', '2026-09-30', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25240, 106, 4, 5, 190046, 'Revisão dos 40 mil km', '2026-09-29 10:50:00', '2026-09-30', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25241, 15, 4, NULL, 161002, 'Cheiro ruim no ar-condicionado', '2026-09-30 12:30:00', '2026-10-03', NULL, 'aberta', 0, NULL, NULL, NULL),
  (25242, 18, 2, NULL, 77479, 'Carro puxando para o lado', '2026-09-30 16:10:00', '2026-10-03', NULL, 'aguardando_aprovacao', 0, NULL, NULL, NULL),
  (25243, 50, 4, 9, 18033, 'Correia dentada no prazo de troca', '2026-09-30 09:20:00', '2026-10-02', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25244, 31, 2, 5, 118648, 'Farol queimado e pane elétrica', '2026-09-30 14:00:00', '2026-10-01', NULL, 'em_execucao', 0, NULL, NULL, NULL),
  (25245, 124, 4, NULL, 127723, 'Troca de óleo vencida pela km', '2026-09-30 16:40:00', '2026-10-03', NULL, 'aguardando_aprovacao', 0, NULL, NULL, NULL),
  (25246, 89, 2, NULL, 19949, 'Motor esquentando', '2026-09-30 13:50:00', '2026-10-01', NULL, 'aberta', 0, NULL, NULL, NULL);

INSERT INTO orcamento (id_os, id_funcionario, data_orcamento, valor_total, status, data_decisao, observacoes) VALUES
  (1, 2, '2026-09-01 16:20:00', 135.00, 'aprovado', '2026-09-01 19:20:00', NULL),
  (2, 3, '2026-09-01 15:40:00', 670.50, 'aprovado', '2026-09-01 17:40:00', NULL),
  (3, 3, '2026-09-01 14:50:00', 684.00, 'aprovado', '2026-09-01 19:50:00', NULL),
  (4, 3, '2026-09-01 18:30:00', 171.00, 'aprovado', '2026-09-01 20:30:00', 'Cliente pediu para usar a peça própria'),
  (5, 2, '2026-09-01 15:10:00', 697.00, 'aprovado', '2026-09-01 19:10:00', NULL),
  (6, 3, '2026-09-01 14:00:00', 662.00, 'aprovado', '2026-09-01 15:00:00', NULL),
  (7, 3, '2026-09-02 18:20:00', 235.00, 'aprovado', '2026-09-03 00:20:00', NULL),
  (8, 2, '2026-09-02 09:00:00', 770.00, 'aprovado', '2026-09-02 12:00:00', 'Cliente pediu para usar a peça própria'),
  (9, 2, '2026-09-02 18:30:00', 1727.00, 'aprovado', '2026-09-02 19:30:00', NULL),
  (10, 2, '2026-09-02 10:30:00', 697.00, 'aprovado', '2026-09-02 11:30:00', NULL),
  (11, 3, '2026-09-02 20:40:00', 574.00, 'aprovado', '2026-09-03 01:40:00', NULL),
  (12, 2, '2026-09-02 17:40:00', 135.00, 'aprovado', '2026-09-02 18:40:00', NULL),
  (13, 2, '2026-09-02 17:20:00', 340.00, 'aprovado', '2026-09-02 19:20:00', NULL),
  (14, 2, '2026-09-03 17:30:00', 114.00, 'aprovado', '2026-09-03 23:30:00', NULL),
  (15, 2, '2026-09-03 13:40:00', 660.00, 'aprovado', '2026-09-03 17:40:00', NULL),
  (16, 3, '2026-09-03 15:50:00', 473.50, 'aprovado', '2026-09-03 18:50:00', 'Cliente pediu para usar a peça própria'),
  (17, 3, '2026-09-03 16:00:00', 420.00, 'aprovado', '2026-09-03 20:00:00', 'Cliente pediu para usar a peça própria'),
  (18, 2, '2026-09-03 12:20:00', 897.00, 'aprovado', '2026-09-03 16:20:00', NULL),
  (19, 2, '2026-09-03 17:40:00', 306.00, 'aprovado', '2026-09-03 22:40:00', 'Cliente pediu para usar a peça própria'),
  (20, 2, '2026-09-04 11:00:00', 440.50, 'aprovado', '2026-09-04 17:00:00', 'Cliente pediu para usar a peça própria'),
  (21, 3, '2026-09-04 14:30:00', 697.00, 'aprovado', '2026-09-04 16:30:00', NULL),
  (22, 2, '2026-09-04 16:30:00', 512.00, 'aprovado', '2026-09-04 17:30:00', NULL),
  (23, 3, '2026-09-04 19:20:00', 1259.00, 'aprovado', '2026-09-04 22:20:00', 'Cliente pediu para usar a peça própria'),
  (24, 3, '2026-09-04 12:40:00', 1169.50, 'aprovado', '2026-09-04 13:40:00', 'Cliente pediu para usar a peça própria'),
  (25, 3, '2026-09-04 11:40:00', 331.00, 'aprovado', '2026-09-04 12:40:00', NULL),
  (26, 2, '2026-09-05 17:00:00', 660.00, 'recusado', '2026-09-05 22:00:00', NULL),
  (27, 3, '2026-09-05 17:20:00', 193.00, 'aprovado', '2026-09-05 20:20:00', NULL),
  (28, 3, '2026-09-05 15:00:00', 178.00, 'aprovado', '2026-09-05 17:00:00', NULL),
  (29, 2, '2026-09-07 16:50:00', 551.00, 'aprovado', '2026-09-07 19:50:00', NULL),
  (30, 3, '2026-09-07 14:00:00', 344.00, 'aprovado', '2026-09-07 17:00:00', NULL),
  (31, 2, '2026-09-07 14:20:00', 340.00, 'aprovado', '2026-09-07 20:20:00', NULL),
  (32, 2, '2026-09-07 14:00:00', 604.00, 'aprovado', '2026-09-07 18:00:00', NULL),
  (33, 3, '2026-09-07 11:50:00', 684.00, 'aprovado', '2026-09-07 15:50:00', NULL),
  (34, 2, '2026-09-07 13:50:00', 150.00, 'aprovado', '2026-09-07 15:50:00', NULL),
  (35, 3, '2026-09-08 15:40:00', 150.00, 'aprovado', '2026-09-08 21:40:00', NULL),
  (36, 3, '2026-09-08 14:20:00', 208.00, 'aprovado', '2026-09-08 18:20:00', NULL),
  (37, 2, '2026-09-08 19:50:00', 689.00, 'aprovado', '2026-09-09 00:50:00', NULL),
  (38, 3, '2026-09-08 17:10:00', 1170.00, 'aprovado', '2026-09-08 18:10:00', NULL),
  (39, 2, '2026-09-08 14:50:00', 572.00, 'aprovado', '2026-09-08 20:50:00', NULL),
  (40, 3, '2026-09-08 10:50:00', 350.00, 'aprovado', '2026-09-08 14:50:00', NULL),
  (41, 2, '2026-09-08 11:50:00', 728.50, 'aprovado', '2026-09-08 14:50:00', NULL),
  (42, 3, '2026-09-09 15:50:00', 1069.50, 'aprovado', '2026-09-09 17:50:00', 'Cliente pediu para usar a peça própria'),
  (43, 3, '2026-09-09 17:40:00', 150.00, 'aprovado', '2026-09-09 21:40:00', NULL),
  (44, 2, '2026-09-09 12:40:00', 350.00, 'aprovado', '2026-09-09 15:40:00', NULL),
  (45, 2, '2026-09-09 12:30:00', 870.00, 'aprovado', '2026-09-09 15:30:00', NULL),
  (46, 3, '2026-09-09 16:20:00', 150.00, 'aprovado', '2026-09-09 17:20:00', NULL),
  (47, 3, '2026-09-10 10:00:00', 350.00, 'aprovado', '2026-09-10 16:00:00', NULL),
  (48, 2, '2026-09-10 18:10:00', 1484.00, 'aprovado', '2026-09-11 00:10:00', NULL),
  (49, 3, '2026-09-10 15:00:00', 310.00, 'aprovado', '2026-09-10 20:00:00', NULL),
  (50, 2, '2026-09-10 15:10:00', 340.00, 'aprovado', '2026-09-10 17:10:00', NULL);
INSERT INTO orcamento (id_os, id_funcionario, data_orcamento, valor_total, status, data_decisao, observacoes) VALUES
  (51, 3, '2026-09-10 17:20:00', 350.00, 'aprovado', '2026-09-10 21:20:00', NULL),
  (52, 2, '2026-09-10 17:50:00', 350.00, 'aprovado', '2026-09-10 18:50:00', NULL),
  (53, 3, '2026-09-10 12:50:00', 150.00, 'aprovado', '2026-09-10 13:50:00', NULL),
  (54, 3, '2026-09-11 13:50:00', 300.00, 'aprovado', '2026-09-11 14:50:00', 'Cliente pediu para usar a peça própria'),
  (55, 3, '2026-09-11 18:30:00', 697.00, 'aprovado', '2026-09-11 19:30:00', NULL),
  (56, 2, '2026-09-11 16:10:00', 430.00, 'aprovado', '2026-09-11 17:10:00', NULL),
  (58, 3, '2026-09-11 17:30:00', 170.50, 'aprovado', '2026-09-11 23:30:00', NULL),
  (59, 2, '2026-09-12 11:50:00', 344.00, 'aprovado', '2026-09-12 14:50:00', NULL),
  (60, 3, '2026-09-12 13:00:00', 338.00, 'aprovado', '2026-09-12 19:00:00', NULL),
  (61, 3, '2026-09-12 20:50:00', 178.00, 'aprovado', '2026-09-13 02:50:00', NULL),
  (62, 2, '2026-09-14 15:20:00', 580.00, 'aprovado', '2026-09-14 18:20:00', NULL),
  (63, 2, '2026-09-14 13:40:00', 870.00, 'aprovado', '2026-09-14 15:40:00', NULL),
  (64, 2, '2026-09-14 11:30:00', 350.00, 'aprovado', '2026-09-14 16:30:00', NULL),
  (65, 3, '2026-09-14 11:00:00', 340.00, 'aprovado', '2026-09-14 17:00:00', NULL),
  (66, 2, '2026-09-14 18:40:00', 204.00, 'aprovado', '2026-09-14 20:40:00', NULL),
  (67, 2, '2026-09-14 15:30:00', 344.00, 'aprovado', '2026-09-14 18:30:00', NULL),
  (68, 2, '2026-09-15 14:10:00', 446.00, 'aprovado', '2026-09-15 15:10:00', NULL),
  (69, 3, '2026-09-15 12:50:00', 916.00, 'aprovado', '2026-09-15 17:50:00', NULL),
  (70, 2, '2026-09-15 17:20:00', 350.00, 'aprovado', '2026-09-15 18:20:00', NULL),
  (71, 3, '2026-09-15 13:10:00', 312.00, 'aprovado', '2026-09-15 18:10:00', 'Cliente pediu para usar a peça própria'),
  (72, 3, '2026-09-15 11:50:00', 580.00, 'aprovado', '2026-09-15 17:50:00', NULL),
  (73, 3, '2026-09-15 16:40:00', 120.00, 'recusado', '2026-09-16 10:40:00', NULL),
  (74, 2, '2026-09-16 12:00:00', 331.00, 'aprovado', '2026-09-16 13:00:00', NULL),
  (75, 2, '2026-09-16 13:20:00', 1757.00, 'aprovado', '2026-09-16 19:20:00', NULL),
  (76, 2, '2026-09-16 16:10:00', 310.00, 'aprovado', '2026-09-16 21:10:00', NULL),
  (77, 2, '2026-09-16 12:30:00', 350.00, 'aprovado', '2026-09-16 13:30:00', NULL),
  (78, 3, '2026-09-16 10:20:00', 464.00, 'aprovado', '2026-09-16 14:20:00', NULL),
  (79, 3, '2026-09-16 18:50:00', 580.00, 'aprovado', '2026-09-16 19:50:00', NULL),
  (80, 2, '2026-09-16 17:50:00', 210.00, 'aprovado', '2026-09-16 22:50:00', NULL),
  (81, 2, '2026-09-17 14:20:00', 331.00, 'recusado', '2026-09-17 16:20:00', NULL),
  (82, 3, '2026-09-17 11:00:00', 1395.00, 'aprovado', '2026-09-17 14:00:00', NULL),
  (83, 2, '2026-09-17 17:30:00', 235.00, 'aprovado', '2026-09-17 18:30:00', NULL),
  (84, 2, '2026-09-17 16:00:00', 1208.00, 'aprovado', '2026-09-17 19:00:00', NULL),
  (86, 2, '2026-09-18 12:20:00', 350.00, 'aprovado', '2026-09-18 15:20:00', NULL),
  (87, 2, '2026-09-18 12:50:00', 135.00, 'aprovado', '2026-09-18 15:50:00', NULL),
  (88, 2, '2026-09-18 13:40:00', 228.00, 'aprovado', '2026-09-18 19:40:00', NULL),
  (89, 3, '2026-09-18 10:20:00', 450.00, 'aprovado', '2026-09-18 13:20:00', 'Cliente pediu para usar a peça própria'),
  (90, 2, '2026-09-18 11:40:00', 120.00, 'aprovado', '2026-09-18 13:40:00', NULL),
  (91, 2, '2026-09-18 19:50:00', 340.00, 'aprovado', '2026-09-19 01:50:00', NULL),
  (92, 2, '2026-09-19 11:00:00', 120.00, 'aprovado', '2026-09-19 17:00:00', NULL),
  (93, 3, '2026-09-19 12:30:00', 998.00, 'aprovado', '2026-09-19 13:30:00', NULL),
  (94, 3, '2026-09-19 12:40:00', 690.00, 'aprovado', '2026-09-19 15:40:00', NULL),
  (95, 2, '2026-09-21 12:20:00', 788.00, 'aprovado', '2026-09-21 16:20:00', 'Cliente pediu para usar a peça própria'),
  (96, 3, '2026-09-21 15:50:00', 1443.00, 'aprovado', '2026-09-21 19:50:00', NULL),
  (97, 2, '2026-09-21 09:40:00', 1540.00, 'aprovado', '2026-09-21 15:40:00', NULL),
  (98, 2, '2026-09-21 16:10:00', 180.00, 'aprovado', '2026-09-21 18:10:00', NULL),
  (99, 2, '2026-09-21 12:30:00', 338.00, 'aprovado', '2026-09-21 16:30:00', 'Cliente pediu para usar a peça própria'),
  (100, 3, '2026-09-21 11:00:00', 350.00, 'aprovado', '2026-09-21 16:00:00', NULL),
  (101, 2, '2026-09-22 16:20:00', 500.00, 'aprovado', '2026-09-22 21:20:00', NULL),
  (102, 2, '2026-09-22 14:40:00', 490.00, 'aprovado', '2026-09-22 19:40:00', 'Cliente pediu para usar a peça própria');
INSERT INTO orcamento (id_os, id_funcionario, data_orcamento, valor_total, status, data_decisao, observacoes) VALUES
  (103, 2, '2026-09-22 12:20:00', 860.00, 'aprovado', '2026-09-22 16:20:00', NULL),
  (104, 2, '2026-09-22 18:30:00', 817.00, 'aprovado', '2026-09-22 21:30:00', NULL),
  (105, 3, '2026-09-22 16:40:00', 120.00, 'aprovado', '2026-09-22 17:40:00', NULL),
  (106, 2, '2026-09-22 13:10:00', 228.50, 'aprovado', '2026-09-22 16:10:00', NULL),
  (107, 3, '2026-09-23 15:10:00', 345.00, 'aprovado', '2026-09-23 17:10:00', NULL),
  (108, 3, '2026-09-23 14:40:00', 675.00, 'aprovado', '2026-09-23 20:40:00', NULL),
  (109, 2, '2026-09-23 11:10:00', 766.00, 'aprovado', '2026-09-23 15:10:00', 'Cliente pediu para usar a peça própria'),
  (110, 2, '2026-09-23 11:30:00', 1410.00, 'aprovado', '2026-09-23 17:30:00', NULL),
  (111, 2, '2026-09-23 14:00:00', 340.00, 'aprovado', '2026-09-23 17:00:00', NULL),
  (112, 2, '2026-09-23 10:00:00', 340.00, 'aprovado', '2026-09-23 11:00:00', NULL),
  (113, 2, '2026-09-24 13:30:00', 260.00, 'aprovado', '2026-09-24 19:30:00', 'Cliente pediu para usar a peça própria'),
  (114, 2, '2026-09-24 18:50:00', 100.00, 'aprovado', '2026-09-24 21:50:00', 'Cliente pediu para usar a peça própria'),
  (115, 2, '2026-09-24 16:10:00', 322.00, 'aprovado', '2026-09-24 20:10:00', NULL),
  (116, 3, '2026-09-24 17:40:00', 208.00, 'aprovado', '2026-09-24 22:40:00', NULL),
  (117, 3, '2026-09-24 18:50:00', 120.00, 'aprovado', '2026-09-24 19:50:00', NULL),
  (118, 2, '2026-09-24 14:20:00', 528.00, 'aprovado', '2026-09-24 18:20:00', NULL),
  (119, 2, '2026-09-25 14:10:00', 870.00, 'aprovado', '2026-09-25 17:10:00', NULL),
  (120, 2, '2026-09-25 12:20:00', 878.00, 'aprovado', '2026-09-25 14:20:00', NULL),
  (121, 3, '2026-09-25 12:00:00', 1045.00, 'aprovado', '2026-09-25 14:00:00', NULL),
  (122, 3, '2026-09-25 15:20:00', 200.50, 'aprovado', '2026-09-25 17:20:00', NULL),
  (123, 3, '2026-09-25 15:50:00', 140.00, 'aprovado', '2026-09-25 17:50:00', 'Cliente pediu para usar a peça própria'),
  (124, 3, '2026-09-25 17:40:00', 825.00, 'aprovado', '2026-09-25 23:40:00', NULL),
  (125, 2, '2026-09-26 19:20:00', 2387.50, 'aprovado', '2026-09-26 22:20:00', NULL),
  (126, 3, '2026-09-26 13:50:00', 1690.00, 'aprovado', '2026-09-26 19:50:00', NULL),
  (127, 3, '2026-09-26 18:30:00', 1219.00, 'aprovado', '2026-09-26 23:30:00', 'Cliente pediu para usar a peça própria'),
  (128, 2, '2026-09-28 17:20:00', 825.00, 'aprovado', '2026-09-28 22:20:00', NULL),
  (129, 3, '2026-09-28 11:50:00', 114.00, 'pendente', NULL, NULL),
  (130, 2, '2026-09-28 13:20:00', 760.00, 'aprovado', '2026-09-28 19:20:00', NULL),
  (131, 3, '2026-09-28 10:10:00', 660.00, 'aprovado', '2026-09-28 12:10:00', NULL),
  (132, 3, '2026-09-28 14:10:00', 1060.00, 'aprovado', '2026-09-28 16:10:00', NULL),
  (133, 3, '2026-09-28 09:20:00', 358.00, 'aprovado', '2026-09-28 14:20:00', 'Cliente pediu para usar a peça própria'),
  (134, 3, '2026-09-28 18:30:00', 870.00, 'aprovado', '2026-09-28 22:30:00', NULL),
  (135, 2, '2026-09-29 18:50:00', 1206.00, 'aprovado', '2026-09-29 22:50:00', NULL),
  (136, 3, '2026-09-29 19:50:00', 870.00, 'aprovado', '2026-09-30 00:50:00', NULL),
  (137, 2, '2026-09-29 11:20:00', 208.00, 'aprovado', '2026-09-29 13:20:00', NULL),
  (138, 2, '2026-09-29 18:40:00', 340.00, 'aprovado', '2026-09-29 20:40:00', NULL),
  (139, 3, '2026-09-29 18:20:00', 150.00, 'aprovado', '2026-09-29 20:20:00', NULL),
  (140, 2, '2026-09-29 11:50:00', 635.00, 'aprovado', '2026-09-29 15:50:00', 'Cliente pediu para usar a peça própria'),
  (142, 2, '2026-09-30 18:10:00', 150.00, 'pendente', NULL, NULL),
  (143, 3, '2026-09-30 11:20:00', 1214.00, 'aprovado', '2026-09-30 15:20:00', NULL),
  (144, 2, '2026-09-30 16:00:00', 170.50, 'aprovado', '2026-09-30 17:00:00', NULL),
  (145, 2, '2026-09-30 20:40:00', 344.00, 'pendente', NULL, NULL);

INSERT INTO item_servico (id_os, id_servico, quantidade, valor_cobrado, retrabalho_garantia) VALUES
  (1, 6, 1, 135.00, 0),
  (2, 1, 1, 120.00, 0),
  (2, 6, 1, 142.50, 0),
  (2, 19, 1, 150.00, 0),
  (3, 4, 1, 180.00, 0),
  (3, 1, 1, 114.00, 0),
  (4, 4, 1, 171.00, 0),
  (5, 2, 1, 350.00, 0),
  (6, 2, 1, 315.00, 0),
  (7, 15, 1, 130.00, 0),
  (8, 2, 1, 350.00, 0),
  (8, 6, 1, 135.00, 0),
  (9, 7, 1, 270.00, 0),
  (9, 2, 1, 350.00, 0),
  (10, 2, 1, 350.00, 0),
  (11, 12, 1, 54.00, 0),
  (12, 6, 1, 135.00, 0),
  (13, 4, 1, 180.00, 0),
  (14, 9, 1, 114.00, 0),
  (15, 16, 1, 280.00, 0),
  (16, 4, 1, 171.00, 0),
  (16, 19, 1, 142.50, 0),
  (17, 1, 1, 120.00, 0),
  (17, 14, 1, 108.00, 0),
  (18, 15, 1, 130.00, 0),
  (18, 2, 1, 315.00, 0),
  (19, 1, 1, 114.00, 0),
  (20, 17, 1, 108.00, 0),
  (20, 19, 1, 142.50, 0),
  (21, 2, 1, 350.00, 0),
  (22, 1, 1, 120.00, 0),
  (22, 10, 1, 162.00, 0),
  (23, 2, 1, 350.00, 0),
  (23, 5, 1, 220.00, 0),
  (24, 3, 1, 427.50, 0),
  (24, 13, 1, 150.00, 0),
  (24, 17, 1, 114.00, 0),
  (25, 4, 1, 171.00, 0),
  (27, 13, 1, 135.00, 0),
  (28, 19, 1, 150.00, 0),
  (29, 19, 1, 150.00, 0),
  (29, 11, 1, 95.00, 0),
  (29, 6, 1, 150.00, 0),
  (30, 1, 1, 114.00, 0),
  (31, 4, 1, 180.00, 0),
  (32, 4, 1, 180.00, 0),
  (32, 6, 1, 150.00, 0),
  (32, 9, 1, 114.00, 0),
  (33, 1, 1, 114.00, 0),
  (33, 4, 1, 180.00, 0);
INSERT INTO item_servico (id_os, id_servico, quantidade, valor_cobrado, retrabalho_garantia) VALUES
  (34, 6, 1, 150.00, 0),
  (35, 6, 1, 150.00, 0),
  (36, 13, 1, 150.00, 0),
  (37, 19, 1, 150.00, 0),
  (37, 4, 1, 180.00, 0),
  (37, 10, 1, 171.00, 0),
  (38, 15, 1, 130.00, 0),
  (38, 20, 1, 90.00, 0),
  (38, 5, 1, 220.00, 0),
  (39, 1, 1, 114.00, 0),
  (39, 11, 1, 100.00, 0),
  (40, 1, 1, 120.00, 0),
  (41, 13, 1, 150.00, 0),
  (41, 20, 1, 85.50, 0),
  (41, 1, 1, 120.00, 0),
  (42, 2, 1, 350.00, 0),
  (42, 3, 1, 427.50, 0),
  (43, 6, 1, 150.00, 0),
  (44, 1, 1, 120.00, 0),
  (45, 3, 1, 450.00, 0),
  (46, 6, 1, 150.00, 0),
  (47, 1, 1, 120.00, 0),
  (48, 9, 1, 120.00, 0),
  (48, 7, 1, 300.00, 0),
  (48, 17, 1, 114.00, 0),
  (49, 17, 1, 120.00, 0),
  (50, 4, 1, 180.00, 0),
  (51, 1, 1, 120.00, 0),
  (52, 1, 1, 120.00, 0),
  (53, 6, 1, 150.00, 0),
  (54, 7, 1, 300.00, 0),
  (55, 2, 1, 350.00, 0),
  (56, 13, 1, 150.00, 0),
  (56, 15, 1, 117.00, 0),
  (58, 20, 1, 85.50, 0),
  (59, 1, 1, 114.00, 0),
  (60, 1, 1, 108.00, 0),
  (61, 19, 1, 150.00, 0),
  (62, 12, 1, 60.00, 0),
  (63, 3, 1, 450.00, 0),
  (64, 1, 1, 120.00, 0),
  (65, 4, 1, 180.00, 0),
  (66, 14, 1, 114.00, 0),
  (67, 1, 1, 114.00, 0),
  (68, 1, 1, 108.00, 0),
  (68, 9, 1, 108.00, 0),
  (69, 19, 1, 150.00, 0),
  (69, 5, 1, 198.00, 0),
  (70, 1, 1, 120.00, 0),
  (71, 1, 1, 120.00, 0);
INSERT INTO item_servico (id_os, id_servico, quantidade, valor_cobrado, retrabalho_garantia) VALUES
  (72, 12, 1, 60.00, 0),
  (74, 4, 1, 171.00, 0),
  (75, 2, 1, 350.00, 0),
  (75, 7, 1, 300.00, 0),
  (76, 17, 1, 120.00, 0),
  (77, 1, 1, 120.00, 0),
  (78, 9, 1, 114.00, 0),
  (78, 1, 1, 120.00, 0),
  (79, 12, 1, 60.00, 0),
  (80, 14, 1, 120.00, 0),
  (82, 5, 1, 209.00, 0),
  (82, 16, 1, 266.00, 0),
  (83, 15, 1, 130.00, 0),
  (84, 7, 1, 270.00, 0),
  (84, 19, 1, 150.00, 0),
  (86, 1, 1, 120.00, 0),
  (87, 6, 1, 135.00, 0),
  (88, 11, 1, 100.00, 0),
  (89, 3, 1, 450.00, 0),
  (90, 9, 1, 120.00, 0),
  (91, 4, 1, 180.00, 0),
  (92, 9, 1, 120.00, 0),
  (93, 1, 1, 108.00, 0),
  (93, 16, 1, 280.00, 0),
  (94, 1, 1, 120.00, 0),
  (94, 4, 1, 180.00, 0),
  (95, 19, 1, 142.50, 0),
  (95, 8, 1, 617.50, 0),
  (96, 1, 1, 120.00, 0),
  (96, 3, 1, 450.00, 0),
  (96, 11, 1, 95.00, 0),
  (97, 8, 1, 650.00, 0),
  (98, 10, 1, 180.00, 0),
  (99, 17, 1, 120.00, 0),
  (99, 11, 1, 90.00, 0),
  (100, 1, 1, 120.00, 0),
  (101, 1, 1, 120.00, 0),
  (101, 6, 1, 150.00, 0),
  (102, 1, 1, 120.00, 0),
  (102, 19, 1, 150.00, 0),
  (103, 2, 1, 315.00, 0),
  (103, 14, 1, 108.00, 0),
  (104, 9, 1, 120.00, 0),
  (104, 2, 1, 350.00, 0),
  (105, 9, 1, 120.00, 0),
  (106, 15, 1, 123.50, 0),
  (107, 14, 1, 120.00, 0),
  (107, 6, 1, 135.00, 0),
  (108, 1, 1, 114.00, 0),
  (108, 4, 1, 171.00, 0);
INSERT INTO item_servico (id_os, id_servico, quantidade, valor_cobrado, retrabalho_garantia) VALUES
  (109, 17, 1, 120.00, 0),
  (109, 6, 1, 150.00, 0),
  (109, 1, 1, 114.00, 0),
  (110, 1, 1, 120.00, 0),
  (110, 7, 1, 300.00, 0),
  (111, 4, 1, 180.00, 0),
  (112, 4, 1, 180.00, 0),
  (113, 9, 1, 120.00, 0),
  (113, 18, 1, 140.00, 0),
  (114, 11, 1, 100.00, 0),
  (115, 4, 1, 162.00, 0),
  (116, 13, 1, 150.00, 0),
  (117, 9, 1, 120.00, 0),
  (118, 19, 1, 150.00, 0),
  (118, 1, 1, 120.00, 0),
  (119, 3, 1, 450.00, 0),
  (120, 17, 1, 108.00, 0),
  (120, 12, 1, 60.00, 0),
  (121, 7, 1, 285.00, 0),
  (122, 13, 1, 142.50, 0),
  (123, 18, 1, 140.00, 0),
  (124, 3, 1, 405.00, 0),
  (125, 8, 1, 650.00, 0),
  (125, 3, 1, 427.50, 0),
  (126, 8, 1, 650.00, 0),
  (126, 6, 1, 150.00, 0),
  (127, 16, 1, 280.00, 0),
  (127, 9, 1, 120.00, 0),
  (127, 5, 1, 209.00, 0),
  (128, 2, 1, 315.00, 0),
  (128, 19, 1, 135.00, 0),
  (129, 9, 1, 114.00, 0),
  (130, 5, 1, 220.00, 0),
  (131, 16, 1, 280.00, 0),
  (132, 7, 1, 300.00, 0),
  (133, 5, 1, 198.00, 0),
  (134, 3, 1, 450.00, 0),
  (135, 9, 1, 108.00, 0),
  (135, 1, 1, 108.00, 0),
  (135, 5, 1, 220.00, 0),
  (136, 3, 1, 450.00, 0),
  (137, 13, 1, 150.00, 0),
  (138, 4, 1, 180.00, 0),
  (139, 6, 1, 150.00, 0),
  (140, 2, 1, 350.00, 0),
  (143, 3, 1, 450.00, 0),
  (143, 1, 1, 114.00, 0),
  (144, 19, 1, 142.50, 0),
  (11, 12, 1, 0.00, 1),
  (8, 2, 1, 0.00, 1);
INSERT INTO item_servico (id_os, id_servico, quantidade, valor_cobrado, retrabalho_garantia) VALUES
  (10, 2, 1, 0.00, 1),
  (18, 15, 1, 0.00, 1),
  (76, 17, 1, 0.00, 1),
  (72, 12, 1, 0.00, 1);

INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES
  (2, 1, 'oficina', NULL, 4, 48.00),
  (2, 2, 'oficina', NULL, 1, 38.00),
  (2, 18, 'oficina', NULL, 1, 28.00),
  (3, 7, 'oficina', NULL, 1, 160.00),
  (3, 1, 'oficina', NULL, 4, 48.00),
  (3, 2, 'oficina', NULL, 1, 38.00),
  (4, NULL, 'cliente', 'Jogo de pastilhas de freio dianteiro (trazida pelo cliente)', 1, 0.00),
  (5, 1, 'oficina', NULL, 4, 48.00),
  (5, 2, 'oficina', NULL, 1, 38.00),
  (5, 3, 'oficina', NULL, 1, 55.00),
  (5, 4, 'oficina', NULL, 1, 62.00),
  (6, 1, 'oficina', NULL, 4, 48.00),
  (6, 2, 'oficina', NULL, 1, 38.00),
  (6, 3, 'oficina', NULL, 1, 55.00),
  (6, 4, 'oficina', NULL, 1, 62.00),
  (7, 14, 'oficina', NULL, 3, 35.00),
  (8, 1, 'oficina', NULL, 4, 48.00),
  (8, 2, 'oficina', NULL, 1, 38.00),
  (8, 3, 'oficina', NULL, 1, 55.00),
  (8, NULL, 'cliente', 'Filtro de combustível (trazida pelo cliente)', 1, 0.00),
  (9, 9, 'oficina', NULL, 2, 380.00),
  (9, 1, 'oficina', NULL, 4, 48.00),
  (9, 2, 'oficina', NULL, 1, 38.00),
  (9, 3, 'oficina', NULL, 1, 55.00),
  (9, 4, 'oficina', NULL, 1, 62.00),
  (10, 1, 'oficina', NULL, 4, 48.00),
  (10, 2, 'oficina', NULL, 1, 38.00),
  (10, 3, 'oficina', NULL, 1, 55.00),
  (10, 4, 'oficina', NULL, 1, 62.00),
  (11, 12, 'oficina', NULL, 1, 520.00),
  (13, 7, 'oficina', NULL, 1, 160.00),
  (15, 15, 'oficina', NULL, 1, 310.00),
  (15, 14, 'oficina', NULL, 2, 35.00),
  (16, 7, 'oficina', NULL, 1, 160.00),
  (16, NULL, 'cliente', 'Lâmpada farol H4 (trazida pelo cliente)', 1, 0.00),
  (17, 1, 'oficina', NULL, 4, 48.00),
  (17, NULL, 'cliente', 'Filtro de óleo (trazida pelo cliente)', 1, 0.00),
  (17, NULL, 'cliente', 'Fluido de freio DOT4 500ml (trazida pelo cliente)', 2, 0.00),
  (18, 14, 'oficina', NULL, 3, 35.00),
  (18, 1, 'oficina', NULL, 4, 48.00),
  (18, 2, 'oficina', NULL, 1, 38.00),
  (18, 3, 'oficina', NULL, 1, 55.00),
  (18, 4, 'oficina', NULL, 1, 62.00),
  (19, 1, 'oficina', NULL, 4, 48.00),
  (19, NULL, 'cliente', 'Filtro de óleo (trazida pelo cliente)', 1, 0.00),
  (20, 16, 'oficina', NULL, 2, 95.00),
  (20, NULL, 'cliente', 'Lâmpada farol H4 (trazida pelo cliente)', 1, 0.00),
  (21, 1, 'oficina', NULL, 4, 48.00),
  (21, 2, 'oficina', NULL, 1, 38.00),
  (21, 3, 'oficina', NULL, 1, 55.00);
INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES
  (21, 4, 'oficina', NULL, 1, 62.00),
  (22, 1, 'oficina', NULL, 4, 48.00),
  (22, 2, 'oficina', NULL, 1, 38.00),
  (23, 1, 'oficina', NULL, 4, 48.00),
  (23, NULL, 'cliente', 'Filtro de óleo (trazida pelo cliente)', 1, 0.00),
  (23, 3, 'oficina', NULL, 1, 55.00),
  (23, 4, 'oficina', NULL, 1, 62.00),
  (23, 8, 'oficina', NULL, 2, 190.00),
  (23, NULL, 'cliente', 'Jogo de pastilhas de freio dianteiro (trazida pelo cliente)', 1, 0.00),
  (24, 6, 'oficina', NULL, 1, 420.00),
  (24, 5, 'oficina', NULL, 1, 58.00),
  (24, NULL, 'cliente', 'Bieleta da suspensão (trazida pelo cliente)', 2, 0.00),
  (25, 7, 'oficina', NULL, 1, 160.00),
  (27, 5, 'oficina', NULL, 1, 58.00),
  (28, 18, 'oficina', NULL, 1, 28.00),
  (29, 18, 'oficina', NULL, 1, 28.00),
  (29, 11, 'oficina', NULL, 4, 32.00),
  (30, 1, 'oficina', NULL, 4, 48.00),
  (30, 2, 'oficina', NULL, 1, 38.00),
  (31, 7, 'oficina', NULL, 1, 160.00),
  (32, 7, 'oficina', NULL, 1, 160.00),
  (33, 1, 'oficina', NULL, 4, 48.00),
  (33, 2, 'oficina', NULL, 1, 38.00),
  (33, 7, 'oficina', NULL, 1, 160.00),
  (36, 5, 'oficina', NULL, 1, 58.00),
  (37, 18, 'oficina', NULL, 1, 28.00),
  (37, 7, 'oficina', NULL, 1, 160.00),
  (38, 14, 'oficina', NULL, 3, 35.00),
  (38, 20, 'oficina', NULL, 1, 85.00),
  (38, 8, 'oficina', NULL, 2, 190.00),
  (38, 7, 'oficina', NULL, 1, 160.00),
  (39, 1, 'oficina', NULL, 4, 48.00),
  (39, 2, 'oficina', NULL, 1, 38.00),
  (39, 11, 'oficina', NULL, 4, 32.00),
  (40, 1, 'oficina', NULL, 4, 48.00),
  (40, 2, 'oficina', NULL, 1, 38.00),
  (41, 5, 'oficina', NULL, 1, 58.00),
  (41, 20, 'oficina', NULL, 1, 85.00),
  (41, 1, 'oficina', NULL, 4, 48.00),
  (41, 2, 'oficina', NULL, 1, 38.00),
  (42, 1, 'oficina', NULL, 4, 48.00),
  (42, 2, 'oficina', NULL, 1, 38.00),
  (42, NULL, 'cliente', 'Filtro de ar do motor (trazida pelo cliente)', 1, 0.00),
  (42, 4, 'oficina', NULL, 1, 62.00),
  (42, NULL, 'cliente', 'Kit correia dentada + tensor (trazida pelo cliente)', 1, 0.00),
  (44, 1, 'oficina', NULL, 4, 48.00),
  (44, 2, 'oficina', NULL, 1, 38.00),
  (45, 6, 'oficina', NULL, 1, 420.00),
  (47, 1, 'oficina', NULL, 4, 48.00),
  (47, 2, 'oficina', NULL, 1, 38.00);
INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES
  (48, 9, 'oficina', NULL, 2, 380.00),
  (48, 16, 'oficina', NULL, 2, 95.00),
  (49, 16, 'oficina', NULL, 2, 95.00),
  (50, 7, 'oficina', NULL, 1, 160.00),
  (51, 1, 'oficina', NULL, 4, 48.00),
  (51, 2, 'oficina', NULL, 1, 38.00),
  (52, 1, 'oficina', NULL, 4, 48.00),
  (52, 2, 'oficina', NULL, 1, 38.00),
  (54, NULL, 'cliente', 'Amortecedor dianteiro (trazida pelo cliente)', 2, 0.00),
  (55, 1, 'oficina', NULL, 4, 48.00),
  (55, 2, 'oficina', NULL, 1, 38.00),
  (55, 3, 'oficina', NULL, 1, 55.00),
  (55, 4, 'oficina', NULL, 1, 62.00),
  (56, 5, 'oficina', NULL, 1, 58.00),
  (56, 14, 'oficina', NULL, 3, 35.00),
  (58, 20, 'oficina', NULL, 1, 85.00),
  (59, 1, 'oficina', NULL, 4, 48.00),
  (59, 2, 'oficina', NULL, 1, 38.00),
  (60, 1, 'oficina', NULL, 4, 48.00),
  (60, 2, 'oficina', NULL, 1, 38.00),
  (61, 18, 'oficina', NULL, 1, 28.00),
  (62, 12, 'oficina', NULL, 1, 520.00),
  (63, 6, 'oficina', NULL, 1, 420.00),
  (64, 1, 'oficina', NULL, 4, 48.00),
  (64, 2, 'oficina', NULL, 1, 38.00),
  (65, 7, 'oficina', NULL, 1, 160.00),
  (66, 13, 'oficina', NULL, 2, 45.00),
  (67, 1, 'oficina', NULL, 4, 48.00),
  (67, 2, 'oficina', NULL, 1, 38.00),
  (68, 1, 'oficina', NULL, 4, 48.00),
  (68, 2, 'oficina', NULL, 1, 38.00),
  (69, 18, 'oficina', NULL, 1, 28.00),
  (69, 8, 'oficina', NULL, 2, 190.00),
  (69, 7, 'oficina', NULL, 1, 160.00),
  (70, 1, 'oficina', NULL, 4, 48.00),
  (70, 2, 'oficina', NULL, 1, 38.00),
  (71, 1, 'oficina', NULL, 4, 48.00),
  (71, NULL, 'cliente', 'Filtro de óleo (trazida pelo cliente)', 1, 0.00),
  (72, 12, 'oficina', NULL, 1, 520.00),
  (74, 7, 'oficina', NULL, 1, 160.00),
  (75, 1, 'oficina', NULL, 4, 48.00),
  (75, 2, 'oficina', NULL, 1, 38.00),
  (75, 3, 'oficina', NULL, 1, 55.00),
  (75, 4, 'oficina', NULL, 1, 62.00),
  (75, 9, 'oficina', NULL, 2, 380.00),
  (76, 16, 'oficina', NULL, 2, 95.00),
  (77, 1, 'oficina', NULL, 4, 48.00),
  (77, 2, 'oficina', NULL, 1, 38.00),
  (78, 1, 'oficina', NULL, 4, 48.00),
  (78, 2, 'oficina', NULL, 1, 38.00);
INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES
  (79, 12, 'oficina', NULL, 1, 520.00),
  (80, 13, 'oficina', NULL, 2, 45.00),
  (82, 8, 'oficina', NULL, 2, 190.00),
  (82, 7, 'oficina', NULL, 1, 160.00),
  (82, 15, 'oficina', NULL, 1, 310.00),
  (82, 14, 'oficina', NULL, 2, 35.00),
  (83, 14, 'oficina', NULL, 3, 35.00),
  (84, 9, 'oficina', NULL, 2, 380.00),
  (84, 18, 'oficina', NULL, 1, 28.00),
  (86, 1, 'oficina', NULL, 4, 48.00),
  (86, 2, 'oficina', NULL, 1, 38.00),
  (88, 11, 'oficina', NULL, 4, 32.00),
  (89, NULL, 'cliente', 'Kit correia dentada + tensor (trazida pelo cliente)', 1, 0.00),
  (91, 7, 'oficina', NULL, 1, 160.00),
  (93, 1, 'oficina', NULL, 4, 48.00),
  (93, 2, 'oficina', NULL, 1, 38.00),
  (93, 15, 'oficina', NULL, 1, 310.00),
  (93, 14, 'oficina', NULL, 2, 35.00),
  (94, 1, 'oficina', NULL, 4, 48.00),
  (94, 2, 'oficina', NULL, 1, 38.00),
  (94, 7, 'oficina', NULL, 1, 160.00),
  (95, 18, 'oficina', NULL, 1, 28.00),
  (95, NULL, 'cliente', 'Kit embreagem (trazida pelo cliente)', 1, 0.00),
  (96, 1, 'oficina', NULL, 4, 48.00),
  (96, 2, 'oficina', NULL, 1, 38.00),
  (96, 6, 'oficina', NULL, 1, 420.00),
  (96, 11, 'oficina', NULL, 4, 32.00),
  (97, 10, 'oficina', NULL, 1, 890.00),
  (99, NULL, 'cliente', 'Bieleta da suspensão (trazida pelo cliente)', 2, 0.00),
  (99, 11, 'oficina', NULL, 4, 32.00),
  (100, 1, 'oficina', NULL, 4, 48.00),
  (100, 2, 'oficina', NULL, 1, 38.00),
  (101, 1, 'oficina', NULL, 4, 48.00),
  (101, 2, 'oficina', NULL, 1, 38.00),
  (102, 1, 'oficina', NULL, 4, 48.00),
  (102, NULL, 'cliente', 'Filtro de óleo (trazida pelo cliente)', 1, 0.00),
  (102, 18, 'oficina', NULL, 1, 28.00),
  (103, 1, 'oficina', NULL, 4, 48.00),
  (103, 2, 'oficina', NULL, 1, 38.00),
  (103, 3, 'oficina', NULL, 1, 55.00),
  (103, 4, 'oficina', NULL, 1, 62.00),
  (103, 13, 'oficina', NULL, 2, 45.00),
  (104, 1, 'oficina', NULL, 4, 48.00),
  (104, 2, 'oficina', NULL, 1, 38.00),
  (104, 3, 'oficina', NULL, 1, 55.00),
  (104, 4, 'oficina', NULL, 1, 62.00),
  (106, 14, 'oficina', NULL, 3, 35.00),
  (107, 13, 'oficina', NULL, 2, 45.00),
  (108, 1, 'oficina', NULL, 4, 48.00),
  (108, 2, 'oficina', NULL, 1, 38.00);
INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES
  (108, 7, 'oficina', NULL, 1, 160.00),
  (109, 16, 'oficina', NULL, 2, 95.00),
  (109, 1, 'oficina', NULL, 4, 48.00),
  (109, NULL, 'cliente', 'Filtro de óleo (trazida pelo cliente)', 1, 0.00),
  (110, 1, 'oficina', NULL, 4, 48.00),
  (110, 2, 'oficina', NULL, 1, 38.00),
  (110, 9, 'oficina', NULL, 2, 380.00),
  (111, 7, 'oficina', NULL, 1, 160.00),
  (112, 7, 'oficina', NULL, 1, 160.00),
  (113, NULL, 'cliente', 'Terminal de direção (trazida pelo cliente)', 2, 0.00),
  (114, NULL, 'cliente', 'Vela de ignição (trazida pelo cliente)', 4, 0.00),
  (115, 7, 'oficina', NULL, 1, 160.00),
  (116, 5, 'oficina', NULL, 1, 58.00),
  (118, 18, 'oficina', NULL, 1, 28.00),
  (118, 1, 'oficina', NULL, 4, 48.00),
  (118, 2, 'oficina', NULL, 1, 38.00),
  (119, 6, 'oficina', NULL, 1, 420.00),
  (120, 16, 'oficina', NULL, 2, 95.00),
  (120, 12, 'oficina', NULL, 1, 520.00),
  (121, 9, 'oficina', NULL, 2, 380.00),
  (122, 5, 'oficina', NULL, 1, 58.00),
  (123, NULL, 'cliente', 'Terminal de direção (trazida pelo cliente)', 2, 0.00),
  (124, 6, 'oficina', NULL, 1, 420.00),
  (125, 10, 'oficina', NULL, 1, 890.00),
  (125, 6, 'oficina', NULL, 1, 420.00),
  (126, 10, 'oficina', NULL, 1, 890.00),
  (127, NULL, 'cliente', 'Bomba d''água (trazida pelo cliente)', 1, 0.00),
  (127, 14, 'oficina', NULL, 2, 35.00),
  (127, 8, 'oficina', NULL, 2, 190.00),
  (127, 7, 'oficina', NULL, 1, 160.00),
  (128, 1, 'oficina', NULL, 4, 48.00),
  (128, 2, 'oficina', NULL, 1, 38.00),
  (128, 3, 'oficina', NULL, 1, 55.00),
  (128, 4, 'oficina', NULL, 1, 62.00),
  (128, 18, 'oficina', NULL, 1, 28.00),
  (130, 8, 'oficina', NULL, 2, 190.00),
  (130, 7, 'oficina', NULL, 1, 160.00),
  (131, 15, 'oficina', NULL, 1, 310.00),
  (131, 14, 'oficina', NULL, 2, 35.00),
  (132, 9, 'oficina', NULL, 2, 380.00),
  (133, NULL, 'cliente', 'Disco de freio dianteiro (trazida pelo cliente)', 2, 0.00),
  (133, 7, 'oficina', NULL, 1, 160.00),
  (134, 6, 'oficina', NULL, 1, 420.00),
  (135, 1, 'oficina', NULL, 4, 48.00),
  (135, 2, 'oficina', NULL, 1, 38.00),
  (135, 8, 'oficina', NULL, 2, 190.00),
  (135, 7, 'oficina', NULL, 1, 160.00),
  (136, 6, 'oficina', NULL, 1, 420.00),
  (137, 5, 'oficina', NULL, 1, 58.00),
  (138, 7, 'oficina', NULL, 1, 160.00);
INSERT INTO item_peca (id_os, id_peca, origem, descricao_peca_cliente, quantidade, valor_unitario) VALUES
  (140, 1, 'oficina', NULL, 4, 48.00),
  (140, 2, 'oficina', NULL, 1, 38.00),
  (140, 3, 'oficina', NULL, 1, 55.00),
  (140, NULL, 'cliente', 'Filtro de combustível (trazida pelo cliente)', 1, 0.00),
  (143, 6, 'oficina', NULL, 1, 420.00),
  (143, 1, 'oficina', NULL, 4, 48.00),
  (143, 2, 'oficina', NULL, 1, 38.00),
  (144, 18, 'oficina', NULL, 1, 28.00);

INSERT INTO compra (id_fornecedor, id_funcionario, data_compra, numero_nota_fiscal, data_recebimento, conferida) VALUES
  (5, 2, '2026-09-05', 'NF349489', '2026-09-07', 1),
  (1, 2, '2026-09-12', 'NF422104', '2026-09-14', 1),
  (1, 2, '2026-09-16', 'NF563106', '2026-09-16', 1),
  (6, 2, '2026-09-19', 'NF229866', '2026-09-21', 1),
  (2, 2, '2026-09-26', 'NF955486', '2026-09-26', 1),
  (6, 2, '2026-09-26', 'NF479957', '2026-09-28', 1),
  (1, 2, '2026-09-29', 'NF334615', '2026-09-30', 0),
  (6, 2, '2026-09-30', NULL, NULL, 0);

INSERT INTO item_compra (id_compra, id_peca, quantidade, custo_unitario) VALUES
  (1, 1, 72, 29.00),
  (1, 3, 14, 27.00),
  (1, 4, 11, 31.00),
  (1, 7, 7, 85.00),
  (1, 9, 6, 230.00),
  (1, 14, 12, 16.00),
  (1, 15, 3, 190.00),
  (2, 1, 52, 29.00),
  (2, 2, 28, 19.50),
  (2, 5, 9, 26.00),
  (2, 6, 4, 260.00),
  (2, 7, 6, 85.00),
  (2, 8, 6, 105.00),
  (2, 16, 8, 48.00),
  (2, 18, 13, 12.00),
  (2, 20, 5, 40.00),
  (3, 12, 3, 360.00),
  (4, 1, 44, 29.00),
  (4, 7, 6, 85.00),
  (4, 9, 6, 230.00),
  (4, 11, 20, 15.00),
  (4, 14, 13, 16.00),
  (5, 10, 3, 560.00),
  (6, 2, 18, 19.50),
  (6, 6, 5, 260.00),
  (6, 8, 6, 105.00),
  (6, 12, 3, 360.00),
  (6, 13, 10, 22.00),
  (6, 16, 6, 48.00),
  (7, 7, 4, 85.00),
  (7, 2, 10, 19.50),
  (8, 10, 2, 560.00);

-- movimentações em ordem cronológica (o trigger confere o saldo a cada saída)

INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_compra, id_os, id_funcionario, motivo) VALUES
  (1, 'entrada', 60, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (2, 'entrada', 25, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (3, 'entrada', 10, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (4, 'entrada', 8, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (5, 'entrada', 8, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (6, 'entrada', 4, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (7, 'entrada', 7, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (8, 'entrada', 6, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (9, 'entrada', 4, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (10, 'entrada', 2, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (11, 'entrada', 24, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (12, 'entrada', 3, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (13, 'entrada', 10, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (14, 'entrada', 12, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (15, 'entrada', 2, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (16, 'entrada', 6, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (17, 'entrada', 6, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (18, 'entrada', 12, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (19, 'entrada', 6, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (20, 'entrada', 4, '2026-08-31 17:00:00', NULL, NULL, 2, 'Inventário inicial (contagem física)'),
  (1, 'saida', 4, '2026-09-01 16:21:00', NULL, 2, 5, NULL),
  (2, 'saida', 1, '2026-09-01 16:21:00', NULL, 2, 5, NULL),
  (18, 'saida', 1, '2026-09-01 16:21:00', NULL, 2, 5, NULL),
  (7, 'saida', 1, '2026-09-01 16:22:00', NULL, 3, 9, NULL),
  (1, 'saida', 4, '2026-09-01 16:22:00', NULL, 3, 9, NULL),
  (2, 'saida', 1, '2026-09-01 16:22:00', NULL, 3, 9, NULL),
  (1, 'saida', 4, '2026-09-01 17:31:00', NULL, 5, 9, NULL),
  (2, 'saida', 1, '2026-09-01 17:31:00', NULL, 5, 9, NULL),
  (3, 'saida', 1, '2026-09-01 17:31:00', NULL, 5, 9, NULL),
  (4, 'saida', 1, '2026-09-01 17:31:00', NULL, 5, 9, NULL),
  (1, 'saida', 4, '2026-09-01 17:32:00', NULL, 6, 6, NULL),
  (2, 'saida', 1, '2026-09-01 17:32:00', NULL, 6, 6, NULL),
  (3, 'saida', 1, '2026-09-01 17:32:00', NULL, 6, 6, NULL),
  (4, 'saida', 1, '2026-09-01 17:32:00', NULL, 6, 6, NULL),
  (14, 'saida', 3, '2026-09-02 16:20:00', NULL, 7, 9, NULL),
  (1, 'saida', 4, '2026-09-02 16:21:00', NULL, 8, 6, NULL),
  (2, 'saida', 1, '2026-09-02 16:21:00', NULL, 8, 6, NULL),
  (3, 'saida', 1, '2026-09-02 16:21:00', NULL, 8, 6, NULL),
  (9, 'saida', 2, '2026-09-02 18:30:00', NULL, 9, 6, NULL),
  (1, 'saida', 4, '2026-09-02 18:30:00', NULL, 9, 6, NULL),
  (2, 'saida', 1, '2026-09-02 18:30:00', NULL, 9, 6, NULL),
  (3, 'saida', 1, '2026-09-02 18:30:00', NULL, 9, 6, NULL),
  (4, 'saida', 1, '2026-09-02 18:30:00', NULL, 9, 6, NULL),
  (1, 'saida', 4, '2026-09-02 18:31:00', NULL, 10, 5, NULL),
  (2, 'saida', 1, '2026-09-02 18:31:00', NULL, 10, 5, NULL),
  (3, 'saida', 1, '2026-09-02 18:31:00', NULL, 10, 5, NULL),
  (4, 'saida', 1, '2026-09-02 18:31:00', NULL, 10, 5, NULL),
  (12, 'saida', 1, '2026-09-02 19:40:00', NULL, 11, 8, NULL),
  (7, 'saida', 1, '2026-09-02 19:42:00', NULL, 13, 5, NULL),
  (15, 'saida', 1, '2026-09-03 18:31:00', NULL, 15, 6, NULL);
INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_compra, id_os, id_funcionario, motivo) VALUES
  (14, 'saida', 2, '2026-09-03 18:31:00', NULL, 15, 6, NULL),
  (7, 'saida', 1, '2026-09-03 18:32:00', NULL, 16, 5, NULL),
  (1, 'saida', 4, '2026-09-03 18:33:00', NULL, 17, 5, NULL),
  (14, 'saida', 3, '2026-09-03 18:34:00', NULL, 18, 7, NULL),
  (1, 'saida', 4, '2026-09-03 18:34:00', NULL, 18, 7, NULL),
  (2, 'saida', 1, '2026-09-03 18:34:00', NULL, 18, 7, NULL),
  (3, 'saida', 1, '2026-09-03 18:34:00', NULL, 18, 7, NULL),
  (4, 'saida', 1, '2026-09-03 18:34:00', NULL, 18, 7, NULL),
  (1, 'saida', 4, '2026-09-03 18:40:00', NULL, 19, 7, NULL),
  (16, 'saida', 2, '2026-09-04 11:00:00', NULL, 20, 7, NULL),
  (1, 'saida', 4, '2026-09-04 16:30:00', NULL, 21, 6, NULL),
  (2, 'saida', 1, '2026-09-04 16:30:00', NULL, 21, 6, NULL),
  (3, 'saida', 1, '2026-09-04 16:30:00', NULL, 21, 6, NULL),
  (4, 'saida', 1, '2026-09-04 16:30:00', NULL, 21, 6, NULL),
  (1, 'saida', 4, '2026-09-04 16:31:00', NULL, 22, 6, NULL),
  (2, 'saida', 1, '2026-09-04 16:31:00', NULL, 22, 6, NULL),
  (1, 'saida', 4, '2026-09-04 19:20:00', NULL, 23, 9, NULL),
  (3, 'saida', 1, '2026-09-04 19:20:00', NULL, 23, 9, NULL),
  (4, 'saida', 1, '2026-09-04 19:20:00', NULL, 23, 9, NULL),
  (8, 'saida', 2, '2026-09-04 19:20:00', NULL, 23, 9, NULL),
  (6, 'saida', 1, '2026-09-04 19:21:00', NULL, 24, 6, NULL),
  (5, 'saida', 1, '2026-09-04 19:21:00', NULL, 24, 6, NULL),
  (7, 'saida', 1, '2026-09-04 19:22:00', NULL, 25, 5, NULL),
  (5, 'saida', 1, '2026-09-05 17:20:00', NULL, 27, 6, NULL),
  (18, 'saida', 1, '2026-09-05 17:21:00', NULL, 28, 5, NULL),
  (1, 'entrada', 72, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (3, 'entrada', 14, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (4, 'entrada', 11, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (7, 'entrada', 7, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (9, 'entrada', 6, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (14, 'entrada', 12, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (15, 'entrada', 3, '2026-09-07 09:00:00', 1, NULL, 4, NULL),
  (18, 'saida', 1, '2026-09-07 16:50:00', NULL, 29, 7, NULL),
  (11, 'saida', 4, '2026-09-07 16:50:00', NULL, 29, 7, NULL),
  (1, 'saida', 4, '2026-09-07 16:51:00', NULL, 30, 8, NULL),
  (2, 'saida', 1, '2026-09-07 16:51:00', NULL, 30, 8, NULL),
  (7, 'saida', 1, '2026-09-07 16:52:00', NULL, 31, 7, NULL),
  (7, 'saida', 1, '2026-09-07 16:53:00', NULL, 32, 5, NULL),
  (1, 'saida', 4, '2026-09-07 16:54:00', NULL, 33, 6, NULL),
  (2, 'saida', 1, '2026-09-07 16:54:00', NULL, 33, 6, NULL),
  (7, 'saida', 1, '2026-09-07 16:54:00', NULL, 33, 6, NULL),
  (5, 'saida', 1, '2026-09-08 14:41:00', NULL, 36, 9, NULL),
  (18, 'saida', 1, '2026-09-08 18:50:00', NULL, 37, 5, NULL),
  (7, 'saida', 1, '2026-09-08 18:50:00', NULL, 37, 5, NULL),
  (14, 'saida', 3, '2026-09-08 18:51:00', NULL, 38, 8, NULL),
  (20, 'saida', 1, '2026-09-08 18:51:00', NULL, 38, 8, NULL),
  (8, 'saida', 2, '2026-09-08 18:51:00', NULL, 38, 8, NULL),
  (7, 'saida', 1, '2026-09-08 18:51:00', NULL, 38, 8, NULL),
  (1, 'saida', 4, '2026-09-08 18:52:00', NULL, 39, 9, NULL),
  (2, 'saida', 1, '2026-09-08 18:52:00', NULL, 39, 9, NULL);
INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_compra, id_os, id_funcionario, motivo) VALUES
  (11, 'saida', 4, '2026-09-08 18:52:00', NULL, 39, 9, NULL),
  (1, 'saida', 4, '2026-09-08 18:53:00', NULL, 40, 5, NULL),
  (2, 'saida', 1, '2026-09-08 18:53:00', NULL, 40, 5, NULL),
  (5, 'saida', 1, '2026-09-08 18:54:00', NULL, 41, 7, NULL),
  (20, 'saida', 1, '2026-09-08 18:54:00', NULL, 41, 7, NULL),
  (1, 'saida', 4, '2026-09-08 18:54:00', NULL, 41, 7, NULL),
  (2, 'saida', 1, '2026-09-08 18:54:00', NULL, 41, 7, NULL),
  (1, 'saida', 4, '2026-09-09 17:50:00', NULL, 42, 9, NULL),
  (2, 'saida', 1, '2026-09-09 17:50:00', NULL, 42, 9, NULL),
  (4, 'saida', 1, '2026-09-09 17:50:00', NULL, 42, 9, NULL),
  (1, 'saida', 4, '2026-09-09 18:41:00', NULL, 44, 9, NULL),
  (2, 'saida', 1, '2026-09-09 18:41:00', NULL, 44, 9, NULL),
  (6, 'saida', 1, '2026-09-09 18:42:00', NULL, 45, 8, NULL),
  (1, 'saida', 4, '2026-09-10 09:00:00', NULL, 47, 8, NULL),
  (2, 'saida', 1, '2026-09-10 09:00:00', NULL, 47, 8, NULL),
  (9, 'saida', 2, '2026-09-10 19:10:00', NULL, 48, 8, NULL),
  (16, 'saida', 2, '2026-09-10 19:10:00', NULL, 48, 8, NULL),
  (16, 'saida', 2, '2026-09-10 19:11:00', NULL, 49, 8, NULL),
  (7, 'saida', 1, '2026-09-10 19:12:00', NULL, 50, 6, NULL),
  (1, 'saida', 4, '2026-09-10 19:13:00', NULL, 51, 9, NULL),
  (2, 'saida', 1, '2026-09-10 19:13:00', NULL, 51, 9, NULL),
  (1, 'saida', 4, '2026-09-10 19:14:00', NULL, 52, 8, NULL),
  (2, 'saida', 1, '2026-09-10 19:14:00', NULL, 52, 8, NULL),
  (1, 'saida', 4, '2026-09-11 16:30:00', NULL, 55, 8, NULL),
  (2, 'saida', 1, '2026-09-11 16:30:00', NULL, 55, 8, NULL),
  (3, 'saida', 1, '2026-09-11 16:30:00', NULL, 55, 8, NULL),
  (4, 'saida', 1, '2026-09-11 16:30:00', NULL, 55, 8, NULL),
  (5, 'saida', 1, '2026-09-11 17:10:00', NULL, 56, 6, NULL),
  (14, 'saida', 3, '2026-09-11 17:10:00', NULL, 56, 6, NULL),
  (20, 'saida', 1, '2026-09-11 17:11:00', NULL, 58, 9, NULL),
  (1, 'saida', 4, '2026-09-12 11:50:00', NULL, 59, 6, NULL),
  (2, 'saida', 1, '2026-09-12 11:50:00', NULL, 59, 6, NULL),
  (1, 'saida', 4, '2026-09-12 12:00:00', NULL, 60, 6, NULL),
  (2, 'saida', 1, '2026-09-12 12:00:00', NULL, 60, 6, NULL),
  (18, 'saida', 1, '2026-09-12 17:50:00', NULL, 61, 9, NULL),
  (1, 'entrada', 52, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (2, 'entrada', 28, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (5, 'entrada', 9, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (6, 'entrada', 4, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (7, 'entrada', 6, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (8, 'entrada', 6, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (16, 'entrada', 8, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (18, 'entrada', 13, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (20, 'entrada', 5, '2026-09-14 09:00:00', 2, NULL, 4, NULL),
  (12, 'saida', 1, '2026-09-14 16:20:00', NULL, 62, 5, NULL),
  (6, 'saida', 1, '2026-09-14 16:21:00', NULL, 63, 6, NULL),
  (1, 'saida', 4, '2026-09-14 16:22:00', NULL, 64, 8, NULL),
  (2, 'saida', 1, '2026-09-14 16:22:00', NULL, 64, 8, NULL),
  (7, 'saida', 1, '2026-09-14 16:23:00', NULL, 65, 5, NULL),
  (13, 'saida', 2, '2026-09-14 16:40:00', NULL, 66, 8, NULL);
INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_compra, id_os, id_funcionario, motivo) VALUES
  (1, 'saida', 4, '2026-09-14 16:41:00', NULL, 67, 8, NULL),
  (2, 'saida', 1, '2026-09-14 16:41:00', NULL, 67, 8, NULL),
  (1, 'saida', 4, '2026-09-15 11:10:00', NULL, 68, 5, NULL),
  (2, 'saida', 1, '2026-09-15 11:10:00', NULL, 68, 5, NULL),
  (18, 'saida', 1, '2026-09-15 11:50:00', NULL, 69, 8, NULL),
  (8, 'saida', 2, '2026-09-15 11:50:00', NULL, 69, 8, NULL),
  (7, 'saida', 1, '2026-09-15 11:50:00', NULL, 69, 8, NULL),
  (1, 'saida', 4, '2026-09-15 15:20:00', NULL, 70, 5, NULL),
  (2, 'saida', 1, '2026-09-15 15:20:00', NULL, 70, 5, NULL),
  (1, 'saida', 4, '2026-09-15 15:21:00', NULL, 71, 7, NULL),
  (12, 'saida', 1, '2026-09-15 15:22:00', NULL, 72, 9, NULL),
  (7, 'saida', 1, '2026-09-16 11:00:00', NULL, 74, 7, NULL),
  (1, 'saida', 4, '2026-09-16 12:20:00', NULL, 75, 6, NULL),
  (2, 'saida', 1, '2026-09-16 12:20:00', NULL, 75, 6, NULL),
  (3, 'saida', 1, '2026-09-16 12:20:00', NULL, 75, 6, NULL),
  (4, 'saida', 1, '2026-09-16 12:20:00', NULL, 75, 6, NULL),
  (9, 'saida', 2, '2026-09-16 12:20:00', NULL, 75, 6, NULL),
  (16, 'saida', 2, '2026-09-16 15:10:00', NULL, 76, 8, NULL),
  (1, 'saida', 4, '2026-09-16 15:11:00', NULL, 77, 8, NULL),
  (2, 'saida', 1, '2026-09-16 15:11:00', NULL, 77, 8, NULL),
  (1, 'saida', 4, '2026-09-16 15:12:00', NULL, 78, 7, NULL),
  (2, 'saida', 1, '2026-09-16 15:12:00', NULL, 78, 7, NULL),
  (12, 'entrada', 3, '2026-09-16 16:20:00', 3, NULL, 4, NULL),
  (12, 'saida', 1, '2026-09-16 16:50:00', NULL, 79, 5, NULL),
  (13, 'saida', 2, '2026-09-16 17:50:00', NULL, 80, 5, NULL),
  (8, 'saida', 2, '2026-09-17 11:00:00', NULL, 82, 7, NULL),
  (7, 'saida', 1, '2026-09-17 11:00:00', NULL, 82, 7, NULL),
  (15, 'saida', 1, '2026-09-17 11:00:00', NULL, 82, 7, NULL),
  (14, 'saida', 2, '2026-09-17 11:00:00', NULL, 82, 7, NULL),
  (14, 'saida', 3, '2026-09-17 14:30:00', NULL, 83, 7, NULL),
  (9, 'saida', 2, '2026-09-17 17:00:00', NULL, 84, 5, NULL),
  (18, 'saida', 1, '2026-09-17 17:00:00', NULL, 84, 5, NULL),
  (1, 'saida', 4, '2026-09-18 12:20:00', NULL, 86, 8, NULL),
  (2, 'saida', 1, '2026-09-18 12:20:00', NULL, 86, 8, NULL),
  (11, 'saida', 4, '2026-09-18 13:51:00', NULL, 88, 8, NULL),
  (7, 'saida', 1, '2026-09-18 16:50:00', NULL, 91, 5, NULL),
  (1, 'saida', 4, '2026-09-19 12:30:00', NULL, 93, 5, NULL),
  (2, 'saida', 1, '2026-09-19 12:30:00', NULL, 93, 5, NULL),
  (15, 'saida', 1, '2026-09-19 12:30:00', NULL, 93, 5, NULL),
  (14, 'saida', 2, '2026-09-19 12:30:00', NULL, 93, 5, NULL),
  (1, 'saida', 4, '2026-09-19 12:31:00', NULL, 94, 5, NULL),
  (2, 'saida', 1, '2026-09-19 12:31:00', NULL, 94, 5, NULL),
  (7, 'saida', 1, '2026-09-19 12:31:00', NULL, 94, 5, NULL),
  (1, 'entrada', 44, '2026-09-21 09:00:00', 4, NULL, 4, NULL),
  (7, 'entrada', 6, '2026-09-21 09:00:00', 4, NULL, 4, NULL),
  (9, 'entrada', 6, '2026-09-21 09:00:00', 4, NULL, 4, NULL),
  (11, 'entrada', 20, '2026-09-21 09:00:00', 4, NULL, 4, NULL),
  (14, 'entrada', 13, '2026-09-21 09:00:00', 4, NULL, 4, NULL),
  (18, 'saida', 1, '2026-09-21 12:20:00', NULL, 95, 8, NULL),
  (1, 'saida', 4, '2026-09-21 14:50:00', NULL, 96, 5, NULL);
INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_compra, id_os, id_funcionario, motivo) VALUES
  (2, 'saida', 1, '2026-09-21 14:50:00', NULL, 96, 5, NULL),
  (6, 'saida', 1, '2026-09-21 14:50:00', NULL, 96, 5, NULL),
  (11, 'saida', 4, '2026-09-21 14:50:00', NULL, 96, 5, NULL),
  (10, 'saida', 1, '2026-09-21 14:51:00', NULL, 97, 7, NULL),
  (11, 'saida', 4, '2026-09-21 14:53:00', NULL, 99, 8, NULL),
  (1, 'saida', 4, '2026-09-21 14:54:00', NULL, 100, 8, NULL),
  (2, 'saida', 1, '2026-09-21 14:54:00', NULL, 100, 8, NULL),
  (1, 'saida', 4, '2026-09-22 13:20:00', NULL, 101, 6, NULL),
  (2, 'saida', 1, '2026-09-22 13:20:00', NULL, 101, 6, NULL),
  (1, 'saida', 4, '2026-09-22 16:40:00', NULL, 102, 8, NULL),
  (18, 'saida', 1, '2026-09-22 16:40:00', NULL, 102, 8, NULL),
  (1, 'saida', 4, '2026-09-22 16:41:00', NULL, 103, 6, NULL),
  (2, 'saida', 1, '2026-09-22 16:41:00', NULL, 103, 6, NULL),
  (3, 'saida', 1, '2026-09-22 16:41:00', NULL, 103, 6, NULL),
  (4, 'saida', 1, '2026-09-22 16:41:00', NULL, 103, 6, NULL),
  (13, 'saida', 2, '2026-09-22 16:41:00', NULL, 103, 6, NULL),
  (1, 'saida', 4, '2026-09-22 16:42:00', NULL, 104, 6, NULL),
  (2, 'saida', 1, '2026-09-22 16:42:00', NULL, 104, 6, NULL),
  (3, 'saida', 1, '2026-09-22 16:42:00', NULL, 104, 6, NULL),
  (4, 'saida', 1, '2026-09-22 16:42:00', NULL, 104, 6, NULL),
  (14, 'saida', 3, '2026-09-22 16:44:00', NULL, 106, 8, NULL),
  (13, 'saida', 2, '2026-09-23 15:10:00', NULL, 107, 5, NULL),
  (1, 'saida', 4, '2026-09-23 15:40:00', NULL, 108, 5, NULL),
  (2, 'saida', 1, '2026-09-23 15:40:00', NULL, 108, 5, NULL),
  (7, 'saida', 1, '2026-09-23 15:40:00', NULL, 108, 5, NULL),
  (16, 'saida', 2, '2026-09-23 15:41:00', NULL, 109, 5, NULL),
  (1, 'saida', 4, '2026-09-23 15:41:00', NULL, 109, 5, NULL),
  (1, 'saida', 4, '2026-09-23 15:42:00', NULL, 110, 9, NULL),
  (2, 'saida', 1, '2026-09-23 15:42:00', NULL, 110, 9, NULL),
  (9, 'saida', 2, '2026-09-23 15:42:00', NULL, 110, 9, NULL),
  (7, 'saida', 1, '2026-09-23 15:43:00', NULL, 111, 8, NULL),
  (7, 'saida', 1, '2026-09-23 15:44:00', NULL, 112, 7, NULL),
  (7, 'saida', 1, '2026-09-24 17:51:00', NULL, 115, 5, NULL),
  (5, 'saida', 1, '2026-09-24 17:52:00', NULL, 116, 8, NULL),
  (18, 'saida', 1, '2026-09-24 17:54:00', NULL, 118, 9, NULL),
  (1, 'saida', 4, '2026-09-24 17:54:00', NULL, 118, 9, NULL),
  (2, 'saida', 1, '2026-09-24 17:54:00', NULL, 118, 9, NULL),
  (6, 'saida', 1, '2026-09-25 15:10:00', NULL, 119, 8, NULL),
  (16, 'saida', 2, '2026-09-25 15:11:00', NULL, 120, 6, NULL),
  (12, 'saida', 1, '2026-09-25 15:11:00', NULL, 120, 6, NULL),
  (9, 'saida', 2, '2026-09-25 15:12:00', NULL, 121, 7, NULL),
  (5, 'saida', 1, '2026-09-25 15:13:00', NULL, 122, 9, NULL),
  (6, 'saida', 1, '2026-09-25 15:15:00', NULL, 124, 5, NULL),
  (10, 'entrada', 3, '2026-09-26 17:51:00', 5, NULL, 4, NULL),
  (10, 'saida', 1, '2026-09-26 18:20:00', NULL, 125, 9, NULL),
  (6, 'saida', 1, '2026-09-26 18:20:00', NULL, 125, 9, NULL),
  (10, 'saida', 1, '2026-09-26 18:21:00', NULL, 126, 7, NULL),
  (14, 'saida', 2, '2026-09-26 18:30:00', NULL, 127, 7, NULL),
  (8, 'saida', 2, '2026-09-26 18:30:00', NULL, 127, 7, NULL),
  (7, 'saida', 1, '2026-09-26 18:30:00', NULL, 127, 7, NULL);
INSERT INTO movimentacao_estoque (id_peca, tipo, quantidade, data_movimentacao, id_compra, id_os, id_funcionario, motivo) VALUES
  (2, 'entrada', 18, '2026-09-28 09:00:00', 6, NULL, 4, NULL),
  (6, 'entrada', 5, '2026-09-28 09:00:00', 6, NULL, 4, NULL),
  (8, 'entrada', 6, '2026-09-28 09:00:00', 6, NULL, 4, NULL),
  (12, 'entrada', 3, '2026-09-28 09:00:00', 6, NULL, 4, NULL),
  (13, 'entrada', 10, '2026-09-28 09:00:00', 6, NULL, 4, NULL),
  (16, 'entrada', 6, '2026-09-28 09:00:00', 6, NULL, 4, NULL),
  (1, 'saida', 4, '2026-09-28 17:20:00', NULL, 128, 5, NULL),
  (2, 'saida', 1, '2026-09-28 17:20:00', NULL, 128, 5, NULL),
  (3, 'saida', 1, '2026-09-28 17:20:00', NULL, 128, 5, NULL),
  (4, 'saida', 1, '2026-09-28 17:20:00', NULL, 128, 5, NULL),
  (18, 'saida', 1, '2026-09-28 17:20:00', NULL, 128, 5, NULL),
  (8, 'saida', 2, '2026-09-28 17:22:00', NULL, 130, 6, NULL),
  (7, 'saida', 1, '2026-09-28 17:22:00', NULL, 130, 6, NULL),
  (15, 'saida', 1, '2026-09-28 17:23:00', NULL, 131, 6, NULL),
  (14, 'saida', 2, '2026-09-28 17:23:00', NULL, 131, 6, NULL),
  (9, 'saida', 2, '2026-09-28 17:24:00', NULL, 132, 5, NULL),
  (7, 'saida', 1, '2026-09-28 17:25:00', NULL, 133, 8, NULL),
  (6, 'saida', 1, '2026-09-28 17:30:00', NULL, 134, 5, NULL),
  (1, 'saida', 4, '2026-09-29 18:50:00', NULL, 135, 7, NULL),
  (2, 'saida', 1, '2026-09-29 18:50:00', NULL, 135, 7, NULL),
  (8, 'saida', 2, '2026-09-29 18:50:00', NULL, 135, 7, NULL),
  (7, 'saida', 1, '2026-09-29 18:50:00', NULL, 135, 7, NULL),
  (6, 'saida', 1, '2026-09-29 18:51:00', NULL, 136, 5, NULL),
  (5, 'saida', 1, '2026-09-29 18:52:00', NULL, 137, 7, NULL),
  (7, 'saida', 1, '2026-09-29 18:53:00', NULL, 138, 6, NULL),
  (1, 'saida', 4, '2026-09-29 18:55:00', NULL, 140, 5, NULL),
  (2, 'saida', 1, '2026-09-29 18:55:00', NULL, 140, 5, NULL),
  (3, 'saida', 1, '2026-09-29 18:55:00', NULL, 140, 5, NULL),
  (6, 'saida', 1, '2026-09-30 10:20:00', NULL, 143, 9, NULL),
  (1, 'saida', 4, '2026-09-30 10:20:00', NULL, 143, 9, NULL),
  (2, 'saida', 1, '2026-09-30 10:20:00', NULL, 143, 9, NULL),
  (18, 'saida', 1, '2026-09-30 16:00:00', NULL, 144, 5, NULL);

INSERT INTO pagamento (id_os, data_pagamento, forma_pagamento, parcelas, valor_pago) VALUES
  (1, '2026-09-03 17:20:00', 'credito', 2, 135.00),
  (2, '2026-09-04 13:40:00', 'credito', 4, 670.50),
  (3, '2026-09-01 14:50:00', 'credito', 1, 684.00),
  (4, '2026-09-04 19:30:00', 'dinheiro', 1, 171.00),
  (5, '2026-09-02 19:10:00', 'credito', 4, 697.00),
  (6, '2026-09-02 14:00:00', 'pix', 1, 662.00),
  (7, '2026-09-02 19:20:00', 'pix', 1, 235.00),
  (8, '2026-09-03 12:00:00', 'pix', 1, 770.00),
  (9, '2026-09-02 22:30:00', 'pix', 1, 863.50),
  (9, '2026-09-03 19:30:00', 'pix', 1, 863.50),
  (10, '2026-09-03 12:30:00', 'debito', 1, 697.00),
  (11, '2026-09-02 20:40:00', 'dinheiro', 1, 574.00),
  (12, '2026-09-02 17:40:00', 'credito', 6, 135.00),
  (13, '2026-09-02 20:20:00', 'pix', 1, 170.00),
  (13, '2026-09-03 19:20:00', 'dinheiro', 1, 170.00),
  (14, '2026-09-04 17:30:00', 'debito', 1, 114.00),
  (15, '2026-09-06 13:40:00', 'pix', 1, 660.00),
  (16, '2026-09-04 12:50:00', 'pix', 1, 473.50),
  (17, '2026-09-05 14:00:00', 'credito', 4, 420.00),
  (18, '2026-09-03 11:20:00', 'debito', 1, 897.00),
  (19, '2026-09-04 19:40:00', 'pix', 1, 91.80),
  (20, '2026-09-05 12:00:00', 'pix', 1, 440.50),
  (21, '2026-09-04 19:30:00', 'pix', 1, 348.50),
  (21, '2026-09-05 15:30:00', 'pix', 1, 348.50),
  (22, '2026-09-04 19:30:00', 'pix', 1, 256.00),
  (22, '2026-09-05 15:30:00', 'pix', 1, 256.00),
  (23, '2026-09-05 18:20:00', 'credito', 6, 1259.00),
  (24, '2026-09-04 14:40:00', 'pix', 1, 584.75),
  (24, '2026-09-07 11:40:00', 'debito', 1, 584.75),
  (25, '2026-09-04 13:40:00', 'credito', 1, 331.00),
  (27, '2026-09-07 17:20:00', 'dinheiro', 1, 193.00),
  (28, '2026-09-05 14:00:00', 'dinheiro', 1, 178.00),
  (29, '2026-09-07 18:50:00', 'dinheiro', 1, 551.00),
  (30, '2026-09-10 17:00:00', 'pix', 1, 344.00),
  (31, '2026-09-07 13:20:00', 'pix', 1, 340.00),
  (32, '2026-09-08 13:00:00', 'dinheiro', 1, 604.00),
  (33, '2026-09-07 15:50:00', 'pix', 1, 342.00),
  (33, '2026-09-07 14:50:00', 'dinheiro', 1, 342.00),
  (34, '2026-09-07 10:50:00', 'dinheiro', 1, 150.00),
  (35, '2026-09-09 18:40:00', 'pix', 1, 150.00),
  (36, '2026-09-09 13:20:00', 'pix', 1, 208.00),
  (37, '2026-09-09 19:50:00', 'pix', 1, 689.00),
  (38, '2026-09-09 17:10:00', 'debito', 1, 1170.00),
  (39, '2026-09-09 14:50:00', 'pix', 1, 572.00),
  (40, '2026-09-08 14:50:00', 'pix', 1, 175.00),
  (40, '2026-09-11 11:50:00', 'dinheiro', 1, 175.00),
  (41, '2026-09-08 16:50:00', 'pix', 1, 364.25),
  (41, '2026-09-10 11:50:00', 'credito', 3, 364.25),
  (42, '2026-09-09 20:50:00', 'pix', 1, 534.75),
  (42, '2026-09-10 17:50:00', 'debito', 1, 534.75);
INSERT INTO pagamento (id_os, data_pagamento, forma_pagamento, parcelas, valor_pago) VALUES
  (43, '2026-09-10 19:40:00', 'dinheiro', 1, 150.00),
  (44, '2026-09-10 11:40:00', 'debito', 1, 350.00),
  (45, '2026-09-12 13:30:00', 'pix', 1, 522.00),
  (46, '2026-09-09 18:20:00', 'debito', 1, 150.00),
  (47, '2026-09-10 13:00:00', 'credito', 4, 350.00),
  (48, '2026-09-11 19:10:00', 'pix', 1, 1484.00),
  (49, '2026-09-11 18:00:00', 'credito', 6, 310.00),
  (50, '2026-09-13 15:10:00', 'debito', 1, 340.00),
  (51, '2026-09-13 17:20:00', 'pix', 1, 350.00),
  (52, '2026-09-11 16:50:00', 'dinheiro', 1, 350.00),
  (53, '2026-09-11 16:50:00', 'credito', 6, 150.00),
  (54, '2026-09-14 13:50:00', 'credito', 4, 90.00),
  (55, '2026-09-12 15:30:00', 'pix', 1, 697.00),
  (56, '2026-09-12 16:10:00', 'dinheiro', 1, 430.00),
  (58, '2026-09-13 20:30:00', 'dinheiro', 1, 85.25),
  (59, '2026-09-12 14:50:00', 'pix', 1, 172.00),
  (59, '2026-09-14 09:50:00', 'credito', 4, 172.00),
  (60, '2026-09-12 16:00:00', 'pix', 1, 169.00),
  (60, '2026-09-13 14:00:00', 'dinheiro', 1, 169.00),
  (61, '2026-09-12 17:50:00', 'debito', 1, 106.80),
  (62, '2026-09-14 17:20:00', 'credito', 1, 580.00),
  (63, '2026-09-14 16:40:00', 'pix', 1, 435.00),
  (63, '2026-09-14 15:40:00', 'credito', 6, 435.00),
  (64, '2026-09-14 14:30:00', 'pix', 1, 175.00),
  (64, '2026-09-16 09:30:00', 'debito', 1, 175.00),
  (65, '2026-09-14 15:00:00', 'pix', 1, 170.00),
  (65, '2026-09-15 14:00:00', 'credito', 2, 170.00),
  (66, '2026-09-14 21:40:00', 'pix', 1, 102.00),
  (66, '2026-09-16 17:40:00', 'pix', 1, 102.00),
  (67, '2026-09-14 18:30:00', 'pix', 1, 172.00),
  (67, '2026-09-14 14:30:00', 'credito', 6, 172.00),
  (68, '2026-09-18 13:10:00', 'pix', 1, 446.00),
  (69, '2026-09-18 11:50:00', 'credito', 2, 916.00),
  (70, '2026-09-17 15:20:00', 'pix', 1, 350.00),
  (71, '2026-09-15 17:10:00', 'pix', 1, 156.00),
  (71, '2026-09-15 15:10:00', 'credito', 1, 156.00),
  (72, '2026-09-16 12:50:00', 'credito', 4, 580.00),
  (74, '2026-09-18 12:00:00', 'credito', 3, 331.00),
  (75, '2026-09-16 15:20:00', 'pix', 1, 878.50),
  (75, '2026-09-18 14:20:00', 'pix', 1, 878.50),
  (76, '2026-09-17 18:10:00', 'credito', 3, 310.00),
  (77, '2026-09-16 16:30:00', 'debito', 1, 210.00),
  (78, '2026-09-18 11:20:00', 'pix', 1, 464.00),
  (79, '2026-09-16 20:50:00', 'pix', 1, 290.00),
  (79, '2026-09-16 19:50:00', 'pix', 1, 290.00),
  (80, '2026-09-17 19:50:00', 'dinheiro', 1, 63.00),
  (82, '2026-09-17 15:00:00', 'pix', 1, 697.50),
  (82, '2026-09-18 14:00:00', 'credito', 3, 697.50),
  (83, '2026-09-17 14:30:00', 'credito', 1, 235.00),
  (84, '2026-09-17 18:00:00', 'dinheiro', 1, 362.40);
INSERT INTO pagamento (id_os, data_pagamento, forma_pagamento, parcelas, valor_pago) VALUES
  (86, '2026-09-18 16:20:00', 'pix', 1, 175.00),
  (86, '2026-09-18 13:20:00', 'pix', 1, 175.00),
  (87, '2026-09-18 17:50:00', 'pix', 1, 67.50),
  (87, '2026-09-20 12:50:00', 'debito', 1, 67.50),
  (88, '2026-09-19 12:40:00', 'credito', 4, 228.00),
  (89, '2026-09-18 14:20:00', 'pix', 1, 225.00),
  (89, '2026-09-19 09:20:00', 'debito', 1, 225.00),
  (90, '2026-09-19 11:40:00', 'pix', 1, 120.00),
  (91, '2026-09-18 19:50:00', 'credito', 1, 204.00),
  (92, '2026-09-21 12:00:00', 'dinheiro', 1, 120.00),
  (93, '2026-09-19 10:30:00', 'pix', 1, 998.00),
  (94, '2026-09-22 12:40:00', 'credito', 6, 690.00),
  (95, '2026-09-24 15:20:00', 'credito', 6, 394.00),
  (96, '2026-09-22 14:50:00', 'debito', 1, 1443.00),
  (97, '2026-09-22 13:40:00', 'credito', 1, 1540.00),
  (98, '2026-09-21 14:10:00', 'pix', 1, 180.00),
  (99, '2026-09-24 09:30:00', 'debito', 1, 338.00),
  (100, '2026-09-22 11:00:00', 'credito', 3, 105.00),
  (101, '2026-09-22 13:20:00', 'pix', 1, 500.00),
  (102, '2026-09-22 19:40:00', 'pix', 1, 245.00),
  (102, '2026-09-22 14:40:00', 'debito', 1, 245.00),
  (103, '2026-09-23 13:20:00', 'credito', 4, 860.00),
  (104, '2026-09-24 18:30:00', 'dinheiro', 1, 817.00),
  (105, '2026-09-22 15:40:00', 'debito', 1, 120.00),
  (106, '2026-09-25 16:10:00', 'credito', 3, 228.50),
  (107, '2026-09-26 16:10:00', 'pix', 1, 345.00),
  (108, '2026-09-24 18:40:00', 'pix', 1, 675.00),
  (109, '2026-09-24 10:10:00', 'dinheiro', 1, 766.00),
  (110, '2026-09-25 09:30:00', 'pix', 1, 1410.00),
  (111, '2026-09-24 12:00:00', 'dinheiro', 1, 340.00),
  (112, '2026-09-25 12:00:00', 'credito', 3, 340.00),
  (113, '2026-09-25 12:30:00', 'credito', 4, 260.00),
  (114, '2026-09-26 16:50:00', 'credito', 1, 100.00),
  (115, '2026-09-24 17:10:00', 'credito', 2, 322.00),
  (116, '2026-09-25 15:40:00', 'pix', 1, 62.40),
  (117, '2026-09-27 18:50:00', 'dinheiro', 1, 60.00),
  (118, '2026-09-25 13:20:00', 'debito', 1, 528.00),
  (119, '2026-09-26 17:10:00', 'pix', 1, 870.00),
  (120, '2026-09-25 16:20:00', 'debito', 1, 878.00),
  (121, '2026-09-25 12:00:00', 'dinheiro', 1, 313.50),
  (122, '2026-09-27 13:20:00', 'debito', 1, 200.50),
  (123, '2026-09-26 13:50:00', 'pix', 1, 140.00),
  (124, '2026-09-26 16:40:00', 'pix', 1, 825.00),
  (125, '2026-09-27 21:20:00', 'pix', 1, 2387.50),
  (126, '2026-09-27 15:50:00', 'dinheiro', 1, 1690.00),
  (127, '2026-09-26 19:30:00', 'dinheiro', 1, 1219.00),
  (128, '2026-09-28 20:20:00', 'pix', 1, 412.50),
  (129, '2026-09-28 15:50:00', 'pix', 1, 57.00),
  (130, '2026-09-29 16:20:00', 'pix', 1, 760.00),
  (131, '2026-09-28 14:10:00', 'pix', 1, 330.00);
INSERT INTO pagamento (id_os, data_pagamento, forma_pagamento, parcelas, valor_pago) VALUES
  (131, '2026-09-28 13:10:00', 'dinheiro', 1, 330.00),
  (133, '2026-10-01 07:00:00', 'dinheiro', 1, 214.80),
  (134, '2026-09-28 22:30:00', 'pix', 1, 435.00),
  (136, '2026-09-29 21:50:00', 'pix', 1, 435.00),
  (139, '2026-09-29 22:20:00', 'pix', 1, 75.00),
  (144, '2026-09-30 20:00:00', 'pix', 1, 85.25);
-- [MASSA FIM]

-- ---------------------------------------------------------------------
-- 5) SELECT com JOIN (consultas do dia a dia)
-- ---------------------------------------------------------------------

-- OS em andamento com cliente, veículo, atendente e mecânico (painel da recepção)
SELECT os.numero_os, os.status, os.data_entrada, os.data_previsao,
       c.nome AS cliente, c.telefone, v.placa, CONCAT(v.marca, ' ', v.modelo) AS veiculo,
       a.nome AS atendente, m.nome AS mecanico
FROM ordem_servico os
JOIN veiculo v          ON v.id_veiculo = os.id_veiculo
JOIN cliente c          ON c.id_cliente = v.id_cliente
JOIN funcionario a      ON a.id_funcionario = os.id_atendente
LEFT JOIN funcionario m ON m.id_funcionario = os.id_mecanico
WHERE os.status NOT IN ('entregue','cancelada')
ORDER BY os.data_entrada;

-- Extrato de uma OS (o que hoje sai por captura de tela): serviços e peças com valores
-- (exemplo: a OS entregue com mais itens; no balcão, troque @os pelo número desejado)
SET @os := (SELECT os.numero_os FROM ordem_servico os JOIN item_peca ip ON ip.id_os = os.id_os
            WHERE os.status = 'entregue' GROUP BY os.numero_os ORDER BY COUNT(*) DESC, os.numero_os LIMIT 1);
SELECT os.numero_os, 'serviço' AS tipo, s.nome_servico AS item, i.quantidade, i.valor_cobrado AS valor_unitario,
       i.quantidade * i.valor_cobrado AS subtotal
FROM ordem_servico os
JOIN item_servico i ON i.id_os = os.id_os
JOIN servico s      ON s.id_servico = i.id_servico
WHERE os.numero_os = @os
UNION ALL
SELECT os.numero_os, CONCAT('peça (', ip.origem, ')'),
       COALESCE(p.nome_peca, ip.descricao_peca_cliente), ip.quantidade, ip.valor_unitario,
       ip.quantidade * ip.valor_unitario
FROM ordem_servico os
JOIN item_peca ip   ON ip.id_os = os.id_os
LEFT JOIN peca p    ON p.id_peca = ip.id_peca
WHERE os.numero_os = @os;

-- ---------------------------------------------------------------------
-- 6) UPDATE
-- ---------------------------------------------------------------------

-- Mecânico terminou o serviço: OS fica pronta e a recepção avisa o cliente
UPDATE ordem_servico
   SET status = 'pronta', cliente_avisado = 1
 WHERE id_os = (SELECT id_os FROM (SELECT MIN(id_os) AS id_os FROM ordem_servico
                                   WHERE status = 'em_execucao') t);

-- RN07: veículo trocou de dono — o vínculo passa para o novo cliente (histórico de OS mantido)
UPDATE veiculo
   SET id_cliente = (SELECT id_cliente FROM (SELECT id_cliente FROM cliente WHERE cpf_cnpj = (
                       SELECT MIN(cpf_cnpj) FROM cliente WHERE tipo_pessoa = 'F')) t)
 WHERE placa = (SELECT placa FROM (SELECT MIN(placa) AS placa FROM veiculo) t2);

-- Reajuste de 5% no preço de referência da troca de óleo
UPDATE servico SET valor_base = ROUND(valor_base * 1.05, 2) WHERE nome_servico = 'Troca de óleo e filtro';

-- ---------------------------------------------------------------------
-- 7) DELETE
-- ---------------------------------------------------------------------

-- Pagamento lançado em duplicidade pela recepção: registra e depois remove o lançamento repetido
INSERT INTO pagamento (id_os, data_pagamento, forma_pagamento, parcelas, valor_pago)
SELECT id_os, data_pagamento, forma_pagamento, parcelas, valor_pago
FROM pagamento ORDER BY id_pagamento DESC LIMIT 1;

DELETE FROM pagamento
 WHERE id_pagamento = (SELECT id_pagamento FROM (SELECT MAX(id_pagamento) AS id_pagamento FROM pagamento) t);

-- Cliente cadastrado por engano (sem veículo): pode ser apagado; com veículo, a FK impede (RESTRICT)
INSERT INTO cliente (nome, tipo_pessoa, cpf_cnpj, telefone, logradouro, numero, bairro, cep, data_cadastro,
                     consentimento_lgpd)
VALUES ('Cadastro Duplicado Teste', 'F', '000.000.001-91', '(11) 90000-0000', 'Av. Osvaldo Pucci', '665',
        'Jardim Nossa Sra. do Carmo', '08270-700', '2026-09-30', 1);

DELETE FROM cliente
 WHERE cpf_cnpj = '000.000.001-91'
   AND NOT EXISTS (SELECT 1 FROM veiculo v WHERE v.id_cliente = cliente.id_cliente);

-- =====================================================================
-- 8) CONSULTAS GERENCIAIS (G01–G12) — problemas P1–P4 e KPIs da seção 1.6 do README
-- =====================================================================

-- G01 — Quais peças estão abaixo do estoque mínimo hoje, e quanto falta comprar?
-- Atende: P1 (sem controle de estoque) · KPI "peças abaixo do mínimo"
SELECT nome_peca, saldo, estoque_minimo, estoque_minimo * 2 - saldo AS sugestao_compra
FROM vw_saldo_estoque
WHERE saldo < estoque_minimo
ORDER BY (saldo / NULLIF(estoque_minimo, 0)), nome_peca;

-- G02 — Quais peças da oficina mais saíram no mês, em quantas OS e em quais veículos?
-- Atende: P1 · RF07 (relatório de peças por mês com modelo e motor dos veículos)
SELECT p.nome_peca, SUM(m.quantidade) AS quantidade_usada, COUNT(DISTINCT m.id_os) AS qtd_os,
       GROUP_CONCAT(DISTINCT CONCAT(v.modelo, ' ', v.motor) ORDER BY v.modelo SEPARATOR ', ') AS veiculos
FROM movimentacao_estoque m
JOIN peca p           ON p.id_peca = m.id_peca
JOIN ordem_servico os ON os.id_os = m.id_os
JOIN veiculo v        ON v.id_veiculo = os.id_veiculo
WHERE m.tipo = 'saida' AND m.data_movimentacao >= '2026-09-01' AND m.data_movimentacao < '2026-10-01'
GROUP BY p.nome_peca
ORDER BY quantidade_usada DESC;

-- G03 — Em quais OS do mês o cliente trouxe a própria peça (sem garantia sobre a peça)?
-- Atende: P2 (sem distinção entre peça do cliente e peça da oficina)
SELECT os.numero_os, os.data_entrada, v.placa, ip.descricao_peca_cliente, ip.quantidade,
       os.garantia_ate AS garantia_mao_de_obra_ate
FROM item_peca ip
JOIN ordem_servico os ON os.id_os = ip.id_os
JOIN veiculo v        ON v.id_veiculo = os.id_veiculo
WHERE ip.origem = 'cliente'
ORDER BY os.data_entrada;

-- G04 — Participação das peças do cliente × peças da oficina no mês
-- Atende: P2 · KPI "% de itens de peça trazidos pelo cliente"
SELECT origem, COUNT(*) AS itens, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS percentual
FROM item_peca
GROUP BY origem;

-- G05 — Histórico completo de um veículo pela placa (busca mais usada no balcão)
-- Atende: P3 (perda de informações e cadastros errados) · RF03
SELECT v.placa, CONCAT(v.marca, ' ', v.modelo, ' ', v.motor, ' ', v.ano) AS veiculo, c.nome AS dono_atual,
       os.numero_os, os.data_entrada, os.km_entrada, os.status, os.problema_relatado, os.observacoes
FROM veiculo v
JOIN cliente c             ON c.id_cliente = v.id_cliente
LEFT JOIN ordem_servico os ON os.id_veiculo = v.id_veiculo
WHERE v.placa = (SELECT placa FROM ordem_servico o2 JOIN veiculo v2 USING (id_veiculo)
                 GROUP BY placa ORDER BY COUNT(*) DESC, placa LIMIT 1)
ORDER BY os.data_entrada;

-- G06 — Busca por parte do nome do cliente: todos os veículos vinculados a ele
-- Atende: P3 · RF03
SELECT c.nome, c.telefone, v.placa, v.marca, v.modelo, v.ano
FROM cliente c
JOIN veiculo v ON v.id_cliente = c.id_cliente
WHERE c.nome LIKE '%Transportes%'
ORDER BY c.nome, v.placa;

-- G07 — Quais OS têm saldo a receber (pagamento parcial) e quanto falta?
-- Atende: P4 (sem controle de pagamento parcial e saldo) · KPI "valor a receber"
SELECT os.numero_os, os.status, c.nome AS cliente, c.telefone,
       t.total_os, t.total_pago, t.saldo_devedor
FROM vw_total_os t
JOIN ordem_servico os ON os.id_os = t.id_os
JOIN veiculo v        ON v.id_veiculo = os.id_veiculo
JOIN cliente c        ON c.id_cliente = v.id_cliente
WHERE t.saldo_devedor > 0 AND os.status IN ('entregue','pronta')
ORDER BY t.saldo_devedor DESC;

-- G08 — Faturamento recebido no mês por forma de pagamento
-- Atende: KPI "faturamento mensal" (meta sugerida a confirmar com os sócios)
SELECT forma_pagamento, COUNT(*) AS pagamentos, SUM(valor_pago) AS total_recebido,
       ROUND(100 * SUM(valor_pago) / SUM(SUM(valor_pago)) OVER (), 1) AS percentual
FROM pagamento
WHERE data_pagamento >= '2026-09-01' AND data_pagamento < '2026-10-01'
GROUP BY forma_pagamento
ORDER BY total_recebido DESC;

-- G09 — Ticket médio das OS entregues no mês (serviços + peças da oficina)
-- Atende: KPI "ticket médio por OS"
SELECT COUNT(*) AS os_entregues, ROUND(AVG(t.total_os), 2) AS ticket_medio,
       ROUND(AVG(t.total_servicos), 2) AS media_mao_de_obra, ROUND(AVG(t.total_pecas), 2) AS media_pecas
FROM vw_total_os t
JOIN ordem_servico os ON os.id_os = t.id_os
WHERE os.status = 'entregue' AND os.data_saida >= '2026-09-01' AND os.data_saida < '2026-10-01';

-- G10 — Tempo médio de permanência do carro na oficina, por mecânico
-- Atende: KPI "tempo médio entre entrada e liberação (horas)" · alocação de mecânicos
SELECT f.nome AS mecanico, COUNT(*) AS os_entregues,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, os.data_entrada, os.data_saida)), 1) AS horas_medias
FROM ordem_servico os
JOIN funcionario f ON f.id_funcionario = os.id_mecanico
WHERE os.status = 'entregue'
GROUP BY f.nome
ORDER BY horas_medias;

-- G11 — Taxa de retrabalho em garantia e taxa de aprovação de orçamentos no mês
-- Atende: KPIs "% de OS com retrabalho de garantia" e "% de orçamentos aprovados"
SELECT
  (SELECT ROUND(100 * COUNT(DISTINCT id_os) / (SELECT COUNT(*) FROM ordem_servico WHERE status = 'entregue'), 1)
     FROM item_servico WHERE retrabalho_garantia = 1) AS pct_os_com_retrabalho,
  (SELECT ROUND(100 * SUM(status = 'aprovado') / SUM(status <> 'pendente'), 1)
     FROM orcamento) AS pct_orcamentos_aprovados;

-- G12 — Serviços mais executados no mês e receita de mão de obra de cada um (inclui trocas de óleo)
-- Atende: RF04 (filtrar por tipo de serviço / relatório de trocas de óleo) · KPI "mix de serviços"
SELECT s.nome_servico, COUNT(*) AS vezes, SUM(i.quantidade * i.valor_cobrado) AS receita_mao_de_obra
FROM item_servico i
JOIN servico s        ON s.id_servico = i.id_servico
JOIN ordem_servico os ON os.id_os = i.id_os
WHERE i.retrabalho_garantia = 0 AND os.data_entrada >= '2026-09-01' AND os.data_entrada < '2026-10-01'
GROUP BY s.nome_servico
ORDER BY vezes DESC, receita_mao_de_obra DESC;

-- =====================================================================
-- 9) CONSULTAS DE AUDITORIA (A01–A10) — conferem as regras de negócio
--    Resultado vazio = regra respeitada. Algumas retornam linhas de propósito
--    (situações reais do dia a dia que a auditoria deve apontar).
-- =====================================================================

-- A01 — Existe OS entregue sem data de saída, sem garantia ou sem nota fiscal?
-- Verifica: RN01 (dados obrigatórios da OS) e RN13 (nota fiscal na entrega)
SELECT numero_os, status, data_saida, garantia_ate, numero_nota_fiscal
FROM ordem_servico
WHERE status = 'entregue' AND (data_saida IS NULL OR garantia_ate IS NULL OR numero_nota_fiscal IS NULL);

-- A02 — Existe OS em execução, pronta ou entregue sem orçamento aprovado?
-- Verifica: RN02 (serviço só é executado depois da aprovação do orçamento)
SELECT os.numero_os, os.status, o.status AS status_orcamento
FROM ordem_servico os
LEFT JOIN orcamento o ON o.id_os = os.id_os
WHERE os.status IN ('em_execucao','pronta','entregue') AND (o.id_orcamento IS NULL OR o.status <> 'aprovado');

-- A03 — O valor cobrado na OS é diferente do orçamento aprovado?
-- Verifica: RN02 (o valor do orçamento aprovado fica travado na OS)
SELECT os.numero_os, o.valor_total AS orcado, t.total_os AS cobrado
FROM orcamento o
JOIN ordem_servico os ON os.id_os = o.id_os
JOIN vw_total_os t    ON t.id_os = o.id_os
WHERE o.status = 'aprovado' AND os.status IN ('pronta','entregue') AND o.valor_total <> t.total_os;

-- A04 — Alguma OS recebeu mais do que o total cobrado?
-- Verifica: RN03 (pagamentos parciais somam no máximo o total da OS)
SELECT numero_os, total_os, total_pago FROM vw_total_os WHERE total_pago > total_os;

-- A05 — Peça do cliente lançada com valor, ou garantia diferente de 3 meses da saída?
-- Verifica: RN04 (garantia de 3 meses na mão de obra; peça do cliente sem cobrança e sem garantia)
SELECT os.numero_os, 'peça do cliente com valor' AS problema
FROM item_peca ip JOIN ordem_servico os ON os.id_os = ip.id_os
WHERE ip.origem = 'cliente' AND ip.valor_unitario > 0
UNION ALL
SELECT numero_os, 'garantia fora de 90 dias'
FROM ordem_servico
WHERE status = 'entregue' AND DATEDIFF(garantia_ate, DATE(data_saida)) <> 90;

-- A06 — Retrabalho de garantia lançado sem observação na OS ou fora do prazo de garantia?
-- Verifica: RN05 (retrabalho na mesma OS, com observação, dentro da garantia)
SELECT os.numero_os, os.garantia_ate, os.observacoes
FROM item_servico i
JOIN ordem_servico os ON os.id_os = i.id_os
WHERE i.retrabalho_garantia = 1 AND (os.observacoes IS NULL OR os.garantia_ate IS NULL);

-- A07 — Alguma peça ficou com saldo negativo?
-- Verifica: RN10 (só sai do estoque o que há em saldo; reforçada pelo trigger)
SELECT nome_peca, saldo FROM vw_saldo_estoque WHERE saldo < 0;

-- A08 — Compra recebida que não gerou entrada no estoque (recebimento sem conferência)?
-- Verifica: RN11 (compra só de fornecedor cadastrado; entrada no estoque após conferência)
SELECT c.id_compra, f.razao_social, c.data_compra, c.data_recebimento, c.conferida
FROM compra c
JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
WHERE c.data_recebimento IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM movimentacao_estoque m WHERE m.id_compra = c.id_compra);

-- A09 — OS aberta por funcionário sem permissão de cadastro, ou orçamento feito por quem não é sócio?
-- Verifica: RN06 (só recepção e sócio autorizado cadastram) e RN15 (orçamento só por sócio)
SELECT os.numero_os, f.nome, f.funcao, 'abriu OS sem permissão' AS problema
FROM ordem_servico os JOIN funcionario f ON f.id_funcionario = os.id_atendente
WHERE f.pode_editar_cadastro = 0
UNION ALL
SELECT os.numero_os, f.nome, f.funcao, 'orçamento feito por não sócio'
FROM orcamento o
JOIN ordem_servico os ON os.id_os = o.id_os
JOIN funcionario f    ON f.id_funcionario = o.id_funcionario
WHERE f.funcao <> 'socio';

-- A10 — Clientes sem consentimento LGPD registrado (dados pessoais sem base registrada)
-- Verifica: RN14 (LGPD: consentimento registrado para guardar dados pessoais)
SELECT c.id_cliente, c.nome, c.data_cadastro,
       (SELECT COUNT(*) FROM veiculo v JOIN ordem_servico os ON os.id_veiculo = v.id_veiculo
         WHERE v.id_cliente = c.id_cliente) AS qtd_os
FROM cliente c
WHERE c.consentimento_lgpd = 0;
