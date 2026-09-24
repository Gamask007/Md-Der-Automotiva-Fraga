

## 1. Caracterização da Organização
*(vale 7,5% — Dimensão Conceitual)*

- **Nome e natureza da organização:** Centro Automotivo Fraga — oficina mecânica, especializada em manutenção de automóveis em geral.
- **Contexto e porte:** Empresa com fins lucrativos, no mercado há 11 anos. Conta atualmente com 9 integrantes: sócios (Piu, Magal e Mineiro), recepcionista (Nicolas) e funcionários (Silberto, Caiu, João, Iran e Léo). Realiza entre 6 e 8 atendimentos por dia, cerca de 132 a 180 por mês.
- **Problemas e necessidades identificados:** Não há controle de estoque de peças; falta diferenciação clara entre a peça trazida pelo próprio cliente e a peça comprada pela oficina (a mão de obra tem garantia de 3 meses, mas a peça trazida pelo cliente não tem garantia); o sistema atual não exporta informações para outros aplicativos nem gera PDF automaticamente (é preciso fazer captura de tela do orçamento); já ocorreram perdas de informações e cadastros de veículos feitos errados por causa do preenchimento manual.
- **Justificativa da escolha:** O Centro Automotivo Fraga foi escolhido por reunir uma quantidade significativa de trabalhadores envolvidos em diferentes etapas do atendimento (sócios, recepcionista e mecânicos), o que torna o mapeamento de processos e responsabilidades mais rico. Além disso, o grupo considerou interessante o fato de a organização já possuir um sistema/banco de dados antigo e com diversos problemas — como ausência de controle de estoque, falta de diferenciação entre peças do cliente e da oficina, perdas de informação e cadastros incorretos —, o que torna esse caso um bom desafio prático para propor um modelo de dados mais completo e estruturado.
- **Evidências da organização:**
  - Google Maps: https://share.google/ZSJaoqi0CiMngDXDz (Centro Automotivo Fraga)
  - Endereço: Av. Osvaldo Pucci, 665 - Jardim Nossa Sra. do Carmo, São Paulo - SP, 08270-700
  - Foto Da Visita <img width="900" height="1600" alt="Imagem" src="https://github.com/user-attachments/assets/61b5e699-b0f4-4de8-b465-553e03a7b20f" />
- **Contato:**
  - Telefone: (11) 2521-3689
  - WhatsApp/Celular: (11) 94711-4629

---

## 2. Processos de Negócio
*(vale 10% — Dimensão Procedimental)*

- **Principais processos mapeados:**
  - **Atendimento ao cliente:** identificação do problema do carro → coleta de dados pessoais, placa do veículo e km (é nesse momento que o atendimento vira OS) → cadastro do cliente → avaliação do veículo → orçamento → execução do serviço → estimativa/comunicação da data de liberação do carro.
  - **Cadastro de clientes:** feito por Nicolas no momento do atendimento, a partir dos dados pessoais do cliente (nome, CPF, endereço, telefone), da placa do veículo e da km informada. É esse cadastro que dá origem à OS.
  - **Responsáveis por etapa:** cadastro (Nicolas); avaliação (Piu, Mineiro e Magal); orçamento (Magal); execução do serviço (mecânico).
  - **Escolha dos serviços:** feita por preenchimento automático de um catálogo com todos os serviços oferecidos (ex.: troca de óleo, revisão, correia dentada etc.), e não por serviços avulsos digitados na hora.
  - **Registro de vendas/serviços:** lançados no sistema/banco de dados; hoje o lançamento do serviço ainda é feito manualmente.
- **Fluxogramas:** *represente visualmente pelo menos os processos-chave (imagens anexadas). Deve ficar claro o fluxo de cada processo e como eles se integram entre si.*

<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/f44cf3cf-6cab-4bcc-a54f-d76155e23abd" />
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

Representa a pessoa (física ou jurídica) atendida pela oficina, cadastrada no primeiro atendimento por Nicolas. Um cliente pode possuir mais de um veículo vinculado ao seu cadastro.

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_cliente | Identificador único do cliente (PK) | Gerado automaticamente pelo sistema |
| nome | Nome completo do cliente. *Exemplo fictício: João da Silva Mendes* | Obrigatório |
| cpf_cnpj | Documento do cliente (CPF ou CNPJ) | Obrigatório; usado como uma das formas de busca rápida |
| endereco | Endereço do cliente | Obrigatório |
| telefone | Contato do cliente | — |

**Veículo**

Representa o automóvel atendido pela oficina. Cada veículo está vinculado a um cliente por meio do relacionamento **possui** (1 cliente — N veículos).

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_veiculo | Identificador único do veículo (PK) | Gerado automaticamente |
| placa | Placa do veículo | Obrigatória e única (UNIQUE); campo mais usado para busca |
| ano | Ano do veículo | — |
| modelo | Modelo do veículo | — |
| motor | Motorização do veículo | — |
| km | Quilometragem atual do veículo | Atualizada a cada atendimento/OS; usada como referência para manutenção do veículo |

**Serviço**

Representa cada tipo de serviço que a oficina oferece (ex.: troca de óleo, revisão, correia dentada), com preço de referência já cadastrado. Relaciona-se com a Ordem de Serviço pelo relacionamento **é utilizado em** (N para N).

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_servico | Identificador único (PK) | Gerado automaticamente |
| nome_servico | Nome do serviço | Obrigatório |
| descricao | Descrição detalhada do serviço | — |
| valor_base | Preço de referência do serviço | Obrigatório — todo serviço do catálogo precisa ter um preço cadastrado |

**Ordem de Serviço (OS)**

Representa o atendimento completo de um veículo, desde a entrada até a liberação. É gerada a partir de um veículo (relacionamento **gera,** 1 veículo — N ordens de serviço) e pode se relacionar com serviços, peças, orçamento e pagamentos.

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_os | Identificador único da ordem (PK) | Gerado automaticamente |
| numero_os | Número da ordem exibido ao cliente | Obrigatório |
| data_entrada | Data de entrada do veículo | Obrigatória |
| data_saida | Data de saída/liberação do veículo | Nula até o veículo ser liberado |
| problema_relatado | Problema relatado pelo cliente | Obrigatório |
| responsavel | Funcionário responsável pelo atendimento (ex.: Nicolas na abertura, mecânico na execução) | — |
| garantia | Prazo/condição de garantia da mão de obra | 3 meses de garantia sobre a mão de obra; peça trazida pelo cliente não tem garantia |
| pronto | Indica se o serviço foi concluído | — |
| avisado | Indica se o cliente já foi avisado de que o veículo está pronto | — |
| observacoes | Anotações gerais (ex.: retrabalho de garantia) | Em caso de garantia, reaproveita a mesma OS e adiciona observação, sem alterar a data de entrada |

**Orçamento**

Representa o orçamento vinculado a uma OS, feito por Magal e/ou Mineiro. Relaciona-se com a Ordem de Serviço pelo relacionamento **pode ter** (1 OS — 0..1 orçamento), já que nem toda OS necessariamente tem um orçamento formal registrado.

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_orcamento | Identificador único (PK) | Gerado automaticamente |
| data | Data em que o orçamento foi feito | Obrigatória |
| valor_total | Valor total orçado | É esse valor que fica travado na OS |
| observacoes | Anotações sobre o orçamento | Opcional |

**Peça**

Representa o controle de estoque de peças da oficina, permitindo registrar quais peças foram usadas em cada OS. Relaciona-se com a Ordem de Serviço pelo relacionamento **é utilizada em** (N para N).

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_peca | Identificador único (PK) | Gerado automaticamente |
| nome_peca | Nome da peça | Obrigatório |
| quantidade | Quantidade em estoque | Deve ser maior ou igual a zero |
| origem | Se a peça foi trazida pelo cliente ou comprada pela oficina | Define se há ou não garantia sobre a peça |
| valor | Preço da peça | Obrigatório quando a peça é comprada pela oficina |

**Pagamento**

Representa cada pagamento recebido referente a uma OS, permitindo controlar pagamentos parcelados ou em várias etapas. Relaciona-se com a Ordem de Serviço pelo relacionamento **possui** (1 OS — N pagamentos).

| Atributo | Descrição | Regra de negócio associada |
|----------|-----------|------------------------------|
| id_pagamento | Identificador único (PK) | Gerado automaticamente |
| forma_pagamento | Forma de pagamento usada | Aceita todas as formas, incluindo parcelamento no crédito |
| parcelas | Número de parcelas, quando aplicável | — |
| valor_pago | Valor recebido | Uma OS pode ter vários pagamentos (parcelado/entrada) |
| saldo | Valor que ainda falta pagar | Calculado (valor total da OS − valor pago) |
| data_pagamento | Data em que o pagamento ocorreu | Obrigatória |

*Mantenha o dicionário organizado e padronizado (mesmo formato de tabela para todas as entidades).*

**Atenção à privacidade:** se forem usados exemplos de valores para ilustrar os atributos, esses exemplos devem ser **fictícios** — não utilize dados reais de clientes, fiéis, beneficiários, doadores ou funcionários da organização (nomes, CPFs, contatos etc.), mesmo que tenham sido observados durante a pesquisa de campo. Os exemplos devem apenas ser **coerentes com as operações reais** observadas.

---

## 6. Modelagem Conceitual (Entidades, Atributos, Relacionamentos)
*(vale 7,5% na dimensão conceitual)*

- **Entidades reconhecidas:** Cliente, Veículo, Serviço, Ordem de Serviço, Orçamento, Peça e Pagamento.
- **Atributos e classificações:** Cliente e Veículo são identificados principalmente por CPF, endereço, telefone e placa; a placa é o campo mais usado nas buscas do dia a dia, seguido do nome do cliente (que retorna todos os veículos vinculados a ele).
- **Relacionamentos pertinentes:**
  - Cliente (1) — **possui** — (N) Veículo — um cliente pode ter vários veículos.
  - Veículo (1) — **gera** — (N) Ordem de Serviço
  - Serviço (N) — **é utilizado em** — (N) Ordem de Serviço
  - Peça (N) — **é utilizada em** — (N) Ordem de Serviço
  - Ordem de Serviço (1) — **pode ter** — (0..1) Orçamento
  - Ordem de Serviço (1) — **possui** — (N) Pagamento
  - Quando um veículo troca de dono, o vínculo Cliente–Veículo é atualizado (todo o cadastro é refeito), em vez de criar um novo veículo.
- **Restrições e políticas organizacionais aplicadas ao modelo:** placa de veículo não pode repetir (UNIQUE); todo serviço do catálogo deve ter preço cadastrado; o valor total da OS vem do orçamento vinculado; apenas Nicolas e Magal podem cadastrar, alterar ou consultar informações no sistema.

---

## 7. Diagrama Entidade-Relacionamento (DER)
*(vale 20% — é o item de maior peso da entrega)*

![DER — Centro Automotivo Fraga] <img width="1536" height="1024" alt="Imagem" src="https://github.com/user-attachments/assets/30899d94-2385-4c07-ab2e-5459d9dc965b" />

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

O modelo foi desenhado a partir dos processos reais observados na visita ao Centro Automotivo Fraga, priorizando simplicidade sem perder as regras de negócio levantadas.

- **Cliente e Veículo como entidades separadas:** optamos por separar Cliente de Veículo, em vez de tratar o veículo como um simples atributo do cliente, porque um mesmo cliente pode ter mais de um veículo, e um veículo pode trocar de dono ao longo do tempo. Separar as entidades permite atualizar o vínculo Cliente–Veículo sem perder o histórico de atendimentos.
- **Cardinalidade 1:N entre Cliente e Veículo (possui):** um cliente pode possuir vários veículos, mas cada veículo tem apenas um cliente responsável em cada momento — por isso não foi modelado como N:N.
- **Ordem de Serviço como entidade central:** a OS concentra as informações operacionais do atendimento (datas, problema relatado, responsável, garantia, status). Ela foi mantida separada de Veículo porque um mesmo veículo passa por várias OS ao longo do tempo (1:N entre Veículo e OS, relacionamento gera), e cada OS representa um evento pontual de atendimento.
- **Serviço e Peça como catálogos separados de OS, com relacionamento N:N:** um serviço (ex.: troca de óleo) pode ser usado em várias OS, e uma OS pode conter vários serviços — por isso o relacionamento é N:N e não 1:N. O mesmo raciocínio vale para Peça: uma peça pode ser usada em várias OS ao longo do tempo, e uma OS pode usar várias peças diferentes. Optamos por não criar entidades intermediárias como "Item da OS" nesta etapa conceitual, já que essa decomposição (com atributos como quantidade e valor unitário por uso) é mais adequada ao modelo lógico/relacional, na próxima etapa do projeto.
- **Orçamento como entidade opcional (0..1) em relação à OS:** nem toda OS tem necessariamente um orçamento formal registrado no sistema (algumas podem ser tratadas diretamente pelo valor combinado), por isso a cardinalidade do lado do Orçamento é 0..1, e não 1 obrigatório.
- **Pagamento separado da OS, com cardinalidade 1:N:** como a oficina aceita pagamento parcelado e em várias etapas, uma única OS pode ter vários registros de pagamento — modelar Pagamento como entidade própria (em vez de um único atributo "valor pago" na OS) foi necessário para representar corretamente entradas, parcelas e saldo devedor.
- **Ausência de uma entidade "Funcionário":** avaliamos incluir uma entidade separada para os funcionários (com relacionamento para OS), mas optamos por manter apenas um atributo `responsavel` de texto na OS nesta etapa conceitual, já que a equipe da oficina é pequena (9 pessoas) e essa informação hoje é usada apenas como referência, sem necessidade de regras adicionais (como permissões por funcionário) neste momento do modelo.
- **Atributos `pronto` e `avisado` na OS:** foram modelados como dois campos distintos (em vez de um único "status") porque representam momentos diferentes do processo — o serviço pode estar pronto sem que o cliente ainda tenha sido avisado — e essa distinção é relevante para a operação da oficina.

---

## 9. Uso de Inteligência Artificial
*(documentação obrigatória — não é opcional se o grupo usou IA em qualquer etapa: pesquisa, escrita, organização de ideias ou revisão de texto)*

Se o grupo usou alguma ferramenta de IA (ChatGPT, Claude, Gemini, Perplexity etc.) em qualquer parte do trabalho, registre **para cada uso relevante**:

| Item | O que registrar |
|------|------------------|
| **Ferramenta e etapa** | Qual IA foi usada e em qual parte do trabalho (ex.: pesquisa sobre o setor da organização, redação do README, organização dos requisitos, revisão ortográfica/gramatical). |
| **Motivação** | Por que o grupo recorreu à IA nesse ponto específico. |
| **Prompt(s) utilizados** | Texto exato (ou muito próximo) do que foi perguntado/pedido à IA. |
| **Resposta recebida** | Resumo ou trecho relevante da resposta da IA. |
| **Fontes consultadas e verificadas** | Se a IA citou fontes/dados, quais foram checadas pelo grupo e como (ex.: comparação com o que foi observado na visita de campo). |
| **Trechos rejeitados ou corrigidos** | O que da resposta da IA foi descartado, editado ou corrigido manualmente, e por quê. |
| **Justificativa da escolha final** | Por que o grupo manteve, adaptou ou rejeitou o que a IA sugeriu. |
| **Reflexão crítica** | Limites, vieses ou erros identificados no uso da IA nessa etapa (ex.: informação desatualizada, alucinação, generalização incorreta sobre o tipo de organização). |

*Se o grupo não usou nenhuma ferramenta de IA, declare isso explicitamente nesta seção.*

O grupo utilizou o Claude (Anthropic) como apoio na organização, redação e revisão do README, nas etapas descritas abaixo.

**Uso 1 — Organização e correção do README**
- **Ferramenta e etapa:** Claude; organização geral do arquivo README.md já com o conteúdo elaborado pelo grupo (seção de contato, dicionário de dados, correção ortográfica).
- **Motivação:** o grupo já tinha o conteúdo levantado na visita de campo, mas precisava organizar, corrigir erros de digitação/ortografia e deixar o dicionário de dados mais explicativo.
- **Prompt(s) utilizados:** pedido para adicionar contato (telefones), corrigir nome do atributo "cliente", explicar melhor as entidades do dicionário, marcar que o preço do serviço é obrigatório, ajustar a descrição do campo de km, corrigir ortografia geral e criar um nome fictício de cliente para exemplo.
- **Resposta recebida:** o Claude reescreveu os trechos indicados, adicionou os telefones informados, incluiu uma frase explicativa antes de cada tabela do dicionário, alterou `valor_base` para obrigatório e sugeriu o nome fictício "João da Silva Mendes".
- **Fontes consultadas e verificadas:** nenhuma fonte externa foi usada nessa etapa; todas as informações vieram do conteúdo já levantado pelo próprio grupo na visita à oficina.
- **Trechos rejeitados ou corrigidos:** nenhum trecho foi rejeitado nesta etapa.

**Uso 2 — Alinhamento do dicionário de dados e da modelagem conceitual com o DER**
- **Ferramenta e etapa:** Claude; ajuste da Seção 5 (Dicionário de Dados) e da Seção 6 (Modelagem Conceitual) para bater exatamente com as entidades, atributos e relacionamentos do diagrama DER já desenhado pelo grupo.
- **Motivação:** o texto do README tinha sido escrito antes do DER final, e por isso havia diferenças (ex.: entidade "Funcionário" e "Item da Ordem de Serviço" existiam no texto mas não no diagrama; a entidade "Peça" e "Orçamento" existiam no diagrama mas não no texto).
- **Prompt(s) utilizados:** envio da imagem do DER com o pedido para que "as informações batam com o diagrama".
- **Resposta recebida:** o Claude reescreveu as tabelas do dicionário de dados usando os nomes de atributos exatamente como aparecem no diagrama (`id_cliente`, `nome_servico`, `numero_os`, `pronto`, `avisado`, `saldo`, `parcelas`, `origem` etc.) e reescreveu a lista de relacionamentos e cardinalidades da Seção 6 para refletir o diagrama (possui, gera, é utilizado em, pode ter, é utilizada em).
- **Fontes consultadas e verificadas:** a imagem do DER enviada pelo próprio grupo foi conferida atributo por atributo antes da reescrita; nenhuma fonte externa foi consultada.
- **Trechos rejeitados ou corrigidos:** as entidades "Funcionário" e "Item da Ordem de Serviço" e os atributos que não apareciam no diagrama (ex.: `data_cadastro`, `status_retirada`, `atendente_id`, `mecanico_id`) foram removidos do texto por não corresponderem ao modelo já validado pelo grupo no diagrama.
- **Justificativa da escolha final:** o grupo manteve a reescrita porque o diagrama já representava a versão final e revisada do modelo de dados; o texto precisava apenas refletir essa mesma versão.
- **Reflexão crítica:** por ser um modelo conceitual (Chen), o diagrama representa relacionamentos N:N diretamente entre Serviço/Peça e Ordem de Serviço, sem uma entidade de ligação explícita — essa simplificação é adequada nesta etapa, mas o grupo está ciente de que, na modelagem lógica/relacional (próximas etapas do projeto), esses relacionamentos N:N provavelmente vão precisar de tabelas associativas com atributos próprios (ex.: quantidade, valor unitário usado).

**Uso 3 — Redação de textos de apoio**
- **Ferramenta e etapa:** Claude; redação da Justificativa da Escolha (Seção 1) e da Justificativa Técnica (Seção 8), a partir dos pontos centrais fornecidos pelo grupo.
- **Motivação:** o grupo já sabia os motivos da escolha da organização e as decisões de modelagem tomadas, mas precisava de ajuda para redigir esses pontos de forma organizada e ortograficamente correta.
- **Prompt(s) utilizados:** para a Seção 1, o grupo informou os dois motivos-chave ("quantidade boa de trabalhadores" e "banco de dados com muitos problemas e muito antigo") e pediu para complementar e organizar ortograficamente. Para a Seção 8, o grupo pediu diretamente para preencher a justificativa técnica, sem informar os motivos previamente.
- **Resposta recebida:** o Claude expandiu os dois motivos da Seção 1 em um parágrafo coeso, e, para a Seção 8, elaborou a justificativa de cada decisão de modelagem (separação Cliente/Veículo, cardinalidades, ausência da entidade Funcionário, atributos `pronto`/`avisado` etc.) com base nas regras de negócio e no diagrama já discutidos ao longo da conversa.
- **Fontes consultadas e verificadas:** nenhuma fonte externa; o conteúdo foi baseado nas regras de negócio, requisitos e diagrama já levantados pelo próprio grupo nas etapas anteriores do trabalho.
- **Trechos rejeitados ou corrigidos:** nenhum trecho foi rejeitado até o momento; o grupo revisará o conteúdo gerado antes da entrega final.
- **Justificativa da escolha final:** o texto foi mantido por refletir fielmente as decisões de modelagem que o grupo já havia tomado ao construir o diagrama.
- **Reflexão crítica:** como o grupo não informou previamente os motivos de cada decisão de modelagem na Seção 8, o texto gerado é uma reconstrução lógica feita pela IA a partir do diagrama e das regras de negócio já registradas — é importante que o grupo revise essa seção e confirme se ela reflete de fato o raciocínio que a equipe teve ao desenhar o modelo, ajustando ou complementando onde necessário.

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

Mayra Anísio Da Gama 48814857
João Pedro F. Antunes 
04971661-1
Diego Pignatari 47515741
Guilherme Da Costa Silva 
04900988-5


