# Entrega 1 — Modelo Conceitual (DER)
### Modelagem de um sistema de gestão de informações para uma organização de pequeno porte

> Este arquivo é o esqueleto do **README.md** do repositório GitHub do seu grupo.
> Preencha cada seção abaixo. Não apague os títulos — apenas substitua as instruções em *itálico* pelo conteúdo do seu projeto.
> O **DER** é anexado separadamente ao repositório (em imagem), mas sua justificativa entra neste README.
>
> **A organização escolhida pode ser de qualquer natureza:** empresa com fins lucrativos (livraria, lanchonete, pet shop), ONG, associação comunitária, cooperativa, instituições religiosas/comunitárias como igrejas, terreiros de religiões de matriz africana (candomblé, umbanda) ou outras. O que muda de um tipo para outro são os processos e as regras específicas — a estrutura do trabalho (levantamento de requisitos, modelagem conceitual, DER) é a mesma para todas. Termos como "empresa" e "negócio" usados abaixo devem ser lidos de forma ampla, no sentido técnico de modelagem de dados (ex.: "regras de negócio" = regras de funcionamento da organização, seja ela comercial, religiosa ou social).
>
> **Importante:** a organização precisa **existir de fato** — não é permitido inventar uma organização fictícia. O levantamento de requisitos e regras de negócio deve ser feito por meio de **pesquisa de campo na própria organização** (visitas, entrevistas com responsáveis, observação dos processos reais), então o grupo só deve escolher uma organização à qual **realmente tenha acesso**. Ao escolher, tomem cuidado com o porte: **nem tão pequena** que não gere dados suficiente para o trabalho (poucos processos, poucas entidades), **nem tão grande/complexa** que fique inviável de modelar nesta primeira etapa do curso.

---

## 1. Caracterização da Organização
*(vale 7,5% — Dimensão Conceitual)*

- **Nome e natureza da organização:** Centro Automotivo Fraga — oficina mecânica, especializada em manutenção de automóveis em geral.
- **Contexto e porte:** Empresa com fins lucrativos, no mercado há 11 anos. Conta atualmente com 9 integrantes: sócios (Piu, Magal e Mineiro), recepcionista (Nicolas) e funcionários (Silberto, Caiu, João, Iran e Léo). Realiza entre 6 e 8 atendimentos por dia, cerca de 132 a 180 por mês.
- **Problemas e necessidades identificados:** Não há controle de estoque de peças; falta diferenciação clara entre a peça trazida pelo próprio cliente e a peça comprada pela oficina (a mão de obra tem garantia de 3 meses, mas a peça trazida pelo cliente não tem garantia); o sistema atual não exporta informações para outros aplicativos nem gera PDF automaticamente (é preciso fazer captura de tela do orçamento); já ocorreram perdas de informações e cadastros de veículos feitos errados por causa do preenchimento manual.
- **Justificativa da escolha:** *por que essa organização foi escolhida e por que ela é um bom caso para o projeto?*
- **Evidências da organização:** *comprove que a organização existe e que o grupo teve acesso a ela — ex.: fotos do local/da visita, link da organização no Google (Google Maps/Google Meu Negócio, site, rede social), endereço completo e forma de contato (telefone, e-mail, responsável pela organização).*

---

## 2. Processos de Negócio
*(vale 10% — Dimensão Procedimental)*

- **Principais processos mapeados:**
  - **Atendimento ao cliente:** identificação do problema do carro → coleta de dados pessoais, placa do veículo e km (é nesse momento que o atendimento vira OS) → cadastro do cliente → avaliação do veículo → orçamento → execução do serviço → estimativa/comunicação da data de liberação do carro.
  - **Responsáveis por etapa:** cadastro (Nicolas); avaliação (Piu, Mineiro e Magal); orçamento (Magal); execução do serviço (mecânico).
  - **Escolha dos serviços:** feita por preenchimento automático de um catálogo com todos os serviços oferecidos (ex.: troca de óleo, revisão, correia dentada etc.), e não por serviços avulsos digitados na hora.
  - **Registro de vendas/serviços:** lançados no sistema/banco de dados; hoje o lançamento do serviço ainda é feito manualmente.
- **Fluxogramas:** *represente visualmente pelo menos os processos-chave (imagens anexadas). Deve ficar claro o fluxo de cada processo e como eles se integram entre si.*

---

## 3. Requisitos do Sistema
*(esta seção e a Seção 4 "Regras de Negócio" DIVIDEM 7,5% na dimensão conceitual — juntas valem 7,5%, não 7,5% cada — + 4% exclusivos desta seção na organização/documentação)*

### 3.1 Requisitos Funcionais
*O que o sistema precisa FAZER (ex.: "o sistema deve permitir registrar uma venda").*
- O sistema deve permitir abrir uma OS a partir dos dados cadastrais do cliente, km do veículo, problema relatado, placa e responsável pelo atendimento.
- Uma OS deve poder conter vários serviços (itens da OS).
- O sistema deve permitir busca rápida por placa (uso mais frequente), por nome do cliente (retornando todos os veículos vinculados a ele) e por CPF.
- O sistema deve permitir filtrar por tipo de serviço (ex.: só trocas de óleo, só correia dentada) e gerar relatório de trocas de óleo.
- O sistema deve permitir exportar orçamentos e OS em PDF automaticamente (hoje isso é feito manualmente, por captura de tela).
- O sistema deve controlar a movimentação de peças (entrada e saída do estoque) e registrar quais peças foram usadas em cada serviço.
- O sistema deve gerar relatório de peças/produtos usados por semana ou mês, indicando em quais veículos foram usados (modelo, ano, motor) e a quantidade de serviços realizados.
- O sistema deve permitir anexar fotos do veículo ao cadastro, como forma de comprovar que os dados registrados estão corretos.

### 3.2 Requisitos Não Funcionais
*Características de qualidade (ex.: desempenho, segurança, usabilidade, disponibilidade).*
- O sistema deve evitar perda de informações e erros de cadastro causados por preenchimento manual (já ocorreram cadastros de veículos feitos errados e sumiço de informações).
- O sistema deve permitir exportação de dados para outros formatos/aplicativos (ex.: Excel, PDF) — hoje inexistente.
- O acesso deve ser restrito: apenas usuários autorizados (hoje, Nicolas e Magal) podem cadastrar, alterar ou excluir informações.

---

## 4. Regras de Negócio
*(esta seção DIVIDE com a Seção 3 "Requisitos do Sistema" os mesmos 7,5% da dimensão conceitual — juntas valem 7,5%, não 7,5% cada — + 4% exclusivos desta seção na documentação. "Regras de negócio" é o termo técnico usado em modelagem de dados para as regras de funcionamento de qualquer organização, com ou sem fins lucrativos)*

- **Regras operacionais:**
  - Toda OS deve registrar: placa, número da ordem, data de entrada, data de saída, garantia e status de retirada (pronto/avisado, ou ainda não retirado pelo cliente).
  - O preço dos serviços vem do orçamento, feito por Magal e/ou Mineiro; é esse valor que fica travado na OS.
  - O sistema aceita todas as formas de pagamento, incluindo parcelamento no crédito; deve registrar a forma de pagamento usada, quanto já foi pago e quanto ainda falta (hoje não existe uma aba específica de pagamento parcial no sistema antigo).
  - A mão de obra tem garantia de 3 meses; peça trazida pelo próprio cliente não tem garantia.
  - Em caso de garantia/retrabalho, a mesma OS é reaproveitada (não se abre uma nova) e a data de entrada original não é alterada — apenas se adiciona uma observação.
  - Apenas Nicolas e Magal estão autorizados a cadastrar, alterar ou consultar as informações no sistema.
  - Os funcionários devem alimentar o sistema conforme a demanda do dia a dia.
  - Quando um veículo troca de dono, é necessário atualizar todo o cadastro (dados do cliente vinculados ao veículo).
- **Restrições organizacionais:** Cada veículo tem seus próprios limites (ex.: quilometragem para manutenção), acompanhados por etiqueta e km — mas esse acompanhamento não é um controle formal feito pela organização, e sim uma referência do próprio veículo/fabricante.

---

## 5. Dicionário de Dados Conceitual (Preliminar)
*(vale 10% — Dimensão Procedimental)*

Para cada entidade identificada, liste:

**Cliente**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| cliente_id | Identificador único do cliente (PK) | Gerado automaticamente pelo sistema |
| nome | Nome do cliente | Obrigatório |
| cpf_cnpj | Documento do cliente | Obrigatório; usado como uma das formas de busca rápida |
| endereço | Endereço do cliente | Obrigatório |
| telefone | Contato do cliente | — |
| data_cadastro | Data em que o cliente foi cadastrado | Gerada automaticamente |

**Veículo**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| veiculo_id | Identificador único do veículo (PK) | Gerado automaticamente |
| cliente_id | Cliente dono do veículo (FK) | Obrigatório; se o veículo trocar de dono, o cadastro precisa ser atualizado |
| placa | Placa do veículo | Obrigatória e única (UNIQUE); campo mais usado para busca |
| marca, modelo, ano | Dados do veículo | — |
| km | Quilometragem do veículo | Registrada a cada atendimento/OS |

**Funcionário**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| funcionario_id | Identificador único (PK) | Gerado automaticamente |
| nome | Nome do funcionário | Obrigatório |
| funcao | Cargo/função na oficina | — |
| status | Ativo/inativo | — |

**Serviço (catálogo)**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| servico_id | Identificador único (PK) | Gerado automaticamente |
| descricao | Nome/descrição do serviço | Obrigatório |
| valor_base | Preço de referência do serviço | Opcional; pode ser sobrescrito na OS |

**Ordem de Serviço (OS)**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| os_id | Identificador único / número da ordem (PK) | Gerado automaticamente |
| cliente_id | Cliente atendido (FK) | Obrigatório |
| veiculo_id | Veículo atendido (FK) | Obrigatório |
| km | Quilometragem informada na entrada | Obrigatório |
| problema_relatado | Problema relatado pelo cliente | Obrigatório |
| atendente_id | Quem fez o cadastro/atendimento (FK Funcionário) | Ex.: Nicolas |
| mecanico_id | Mecânico responsável pela execução (FK Funcionário) | — |
| data_abertura | Data de entrada do veículo | Obrigatória |
| data_saida | Data de saída/liberação do veículo | Nula até o veículo ser liberado |
| garantia | Prazo/condição de garantia da mão de obra | 3 meses de garantia sobre a mão de obra; peça trazida pelo cliente não tem garantia |
| status_retirada | Se o carro está pronto, avisado ao cliente, ou ainda não retirado | — |
| observacoes | Anotações gerais (ex.: retrabalho de garantia) | Em caso de garantia, reaproveita a mesma OS e adiciona observação, sem alterar a data de entrada |

**Item da Ordem de Serviço**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| item_id | Identificador único (PK) | Gerado automaticamente |
| os_id | OS à qual pertence (FK) | Obrigatório |
| servico_id | Serviço executado (FK) | Obrigatório |
| quantidade | Quantidade do serviço | Deve ser maior que zero |
| valor_unitario | Valor "travado" no momento do lançamento | Não muda se o preço do catálogo mudar depois |
| desconto | Desconto aplicado ao item | Opcional |
| valor_total_item | Valor total do item | Calculado (quantidade × valor_unitario − desconto) |
| funcionario_executor_id | Quem executou o item (FK) | Opcional |

**Pagamento**

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| pagamento_id | Identificador único (PK) | Gerado automaticamente |
| os_id | OS relacionada (FK) | Obrigatório |
| data_pagamento | Data em que o pagamento ocorreu | Obrigatória |
| valor_pago | Valor recebido | Uma OS pode ter vários pagamentos (parcelado/entrada) |
| valor_pendente | Valor que ainda falta pagar | Calculado (total da OS − valor pago) |
| forma_pagamento | Forma de pagamento usada | Aceita todas as formas, incluindo parcelamento no crédito |
| status_pagamento | pago / pendente / estornado | Hoje o sistema antigo não tem uma aba específica de pagamento parcial |

*Mantenha o dicionário organizado e padronizado (mesmo formato de tabela para todas as entidades).*

**Atenção à privacidade:** se forem usados exemplos de valores para ilustrar os atributos, esses exemplos devem ser **fictícios** — não utilize dados reais de clientes, fiéis, beneficiários, doadores ou funcionários da organização (nomes, CPFs, contatos etc.), mesmo que tenham sido observados durante a pesquisa de campo. Os exemplos devem apenas ser **coerentes com as operações reais** observadas.

---

## 6. Modelagem Conceitual (Entidades, Atributos, Relacionamentos)
*(vale 7,5% na dimensão conceitual)*

- **Entidades reconhecidas:** Cliente, Veículo, Funcionário, Serviço (catálogo), Ordem de Serviço, Item da Ordem de Serviço (tabela de ligação entre OS e Serviço) e Pagamento.
- **Atributos e classificações:** Cliente e Veículo são identificados principalmente por CPF, endereço, telefone e placa; a placa é o campo mais usado nas buscas do dia a dia, seguido do nome do cliente (que retorna todos os veículos vinculados a ele).
- **Relacionamentos pertinentes:**
  - Cliente (1) — (N) Veículo — um cliente pode ter vários veículos.
  - Cliente (1) — (N) Ordem de Serviço
  - Veículo (1) — (N) Ordem de Serviço
  - Ordem de Serviço (1) — (N) Pagamento
  - Ordem de Serviço (1) — (N) Item da Ordem de Serviço
  - Serviço (1) — (N) Item da Ordem de Serviço
  - Funcionário (1) — (N) Ordem de Serviço, tanto como atendente/cadastro (ex.: Nicolas) quanto como mecânico executor
  - Quando um veículo troca de dono, o vínculo Cliente–Veículo é atualizado (todo o cadastro é refeito), em vez de criar um novo veículo.
- **Restrições e políticas organizacionais aplicadas ao modelo:** placa de veículo não pode repetir (UNIQUE); a OS só pode ser finalizada se tiver ao menos 1 item; o valor total da OS é a soma dos valores dos itens; apenas Nicolas e Magal podem cadastrar, alterar ou consultar informações no sistema.

---

## 7. Diagrama Entidade-Relacionamento (DER)
*(vale 20% — é o item de maior peso da entrega)*

- Anexe o DER (em imagem).

![DER — Centro Automotivo Fraga (Mecânica)](DER_Centro_Automotivo_Fraga.jpg)

- O diagrama deve representar corretamente:
  - Entidades
  - Atributos
  - Relacionamentos
  - **Cardinalidades**
- O modelo deve ser **consistente** e já demonstrar potencial de **escalabilidade e integração** (pensando nas próximas etapas do projeto).

---

## 8. Justificativa Técnica
*(vale 7,5% — sozinho, é o subcritério de maior peso dentro da Dimensão Conceitual)*

*Explique e defenda as decisões de abstração e modelagem tomadas: por que essas entidades, esses atributos, esses relacionamentos e essas cardinalidades — e não outras alternativas possíveis?*

### Justificativa técnica

A gente montou o DER pensando nas informações que foram consideradas mais importantes para o funcionamento da oficina. Foi definido que seria necessário ter os dados dos clientes, dos veículos, dos serviços realizados, das ordens de serviço e dos pagamentos, então essas informações foram colocadas no banco. Também relacionamos esses dados de acordo com a forma que a oficina funciona, por exemplo, um cliente pode ter mais de um veículo e um veículo pode ter várias ordens de serviço. A gente não colocou outras informações que não fossem necessárias porque isso deixaria o banco com muitos dados e poderia dificultar a organização. Então, procuramos colocar somente o que realmente seria útil para o sistema e para o controle da oficina.

---

## 9. Uso de Inteligência Artificial
*(documentação obrigatória — não é opcional se o grupo usou IA em qualquer etapa: pesquisa, escrita, organização de ideias ou revisão de texto)*

Se o grupo usou alguma ferramenta de IA (ChatGPT, Claude, Gemini, Perplexity etc.) em qualquer parte do trabalho, registre **para cada uso relevante**:

|Item                                |Registro                                                                                                                                                                                                                                                                              |
|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Ferramenta e etapa**              |Claude (Anthropic) foi usado para revisar as respostas da entrevista de campo feita na oficina e redigir o README a partir do esqueleto fornecido pelo professor — preenchimento das Seções 1, 4, 5 e 6.                                                                      |
|**Motivação**                       |O grupo já tinha feito a pesquisa de campo (entrevista com os responsáveis pela oficina) e precisava organizar as respostas dentro da estrutura exigida pelo esqueleto do README, distribuindo cada informação na seção correta.                                                      |
|**Prompt(s) utilizados**            |O grupo enviou o esqueleto do README e as respostas da entrevista (perguntas de caracterização da empresa, processos, sistema, regras e um roteiro específico de mapeamento do banco de dados) e pediu para "revisar essas informações no md", nas seções correspondentes.            |
|**Resposta recebida**               |A IA distribuiu as respostas como forma de revisão da entrevista dentro das seções do esqueleto como um exemplo (Caracterização da Organização, Processos de Negócio, Requisitos Funcionais/Não Funcionais, Regras de Negócio, Dicionário de Dados e Modelagem Conceitual) e trazendo o apontamento de que seria em formato de tópicos.|
|**Fontes consultadas e verificadas**|Não foram usadas fontes externas — todo o conteúdo veio das respostas dadas pelos próprios sócios/funcionários da oficina na entrevista de campo.                                                                                                                                     |
|**Trechos rejeitados ou corrigidos**|Numa primeira tentativa, a IA criou uma seção nova ("Roteiro de Entrevista") fora da estrutura do esqueleto; o grupo pediu para não alterar a estrutura e apenas revisar as informações nas seções já existentes, o que foi feito.                                               |
|**Justificativa da escolha final**  |O grupo optou por manter a estrutura original do esqueleto (sem seções extras), pois foi essa a exigência do professor, e usar a IA apenas como apoio para revisar o conteúdo já levantado em campo.                                                                      |
|**Reflexão crítica**                |* Como o conteúdo das seções foi revisados pela IA a partir das respostas brutas da entrevista, corríamos o risco de alguma resposta ter sido formalizada ou generalizada de um jeito que não reflete exatamente o que foi dito pela oficina. Por isso, o grupo revisou cada seção comparando com as respostas originais da entrevista antes da entrega.

*Se o grupo não usou nenhuma ferramenta de IA, declare isso explicitamente nesta seção.*

---

## Critérios Atitudinais (20%)
**Estes critérios NÃO constam explicitamente como item de entrega no README.** Eles são avaliados por meio de **Avaliação 360º entre os integrantes do grupo** (cada membro avalia os colegas de equipe) e, no caso da Colaboração, também pela **colaboração equilibrada no histórico de commits** do repositório GitHub — não pela leitura do restante do repositório nem pela apresentação:

- **Participação (5%):** envolvimento nas discussões técnicas e nas decisões do grupo.
- **Comprometimento (5%):** cumprimento de prazos e responsabilidades assumidas.
- **Colaboração (5%):** respeito às contribuições dos colegas, cooperação na construção do projeto e colaboração equilibrada no histórico de commits do repositório GitHub.
- **Autonomia (5%):** busca independente de soluções e proposta de melhorias.

---

## Resumo dos Pesos

| Dimensão | Peso total |
|----------|-----------|
| Conceitual (contexto, requisitos/regras, modelagem, justificativa técnica) | 30% |
| Procedimental (requisitos, fluxogramas, dicionário de dados, DER) | 50% |
| Atitudinal (participação, comprometimento, colaboração, autonomia) | 20% |

**Entrega final:** README.md completo + DER anexado no repositório GitHub do grupo.
