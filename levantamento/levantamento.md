# Levantamento — Centro Automotivo Fraga

Este é o texto organizado do grupo sobre o que foi levantado na oficina. Ele não é a transcrição da entrevista. O resumo está no [README](../README.md#11-revisão-do-modelo-conceitual).

> A visita foi em 11/09/2026. Os pontos novos da Entrega 2 (compras, nota fiscal, agendamento, aprovação do orçamento, estoque, financeiro) foram confirmados depois pelo grupo com a oficina. Declarado: o integrante João Pedro trabalha na oficina.

## 1. Visitas

| Visita | Data | Local | Quem atendeu | Integrantes presentes | Evidência |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1ª (Entrega 1) | 11/09/2026, à tarde | Av. Osvaldo Pucci, 665 — Jardim Nossa Sra. do Carmo, São Paulo/SP | Nicolas (recepcionista) | Mayra, João Pedro, Diego e Guilherme | [foto da visita](../evidencias/foto-visita-2026-09-11.jpg) |

**Responsável pela organização:** Nicolas (recepcionista) — (11) 95310-5009. Os contatos da oficina são (11) 2521-3689 (fixo) e (11) 94711-4629 (WhatsApp).

## 2. A organização em números

| Item | Valor | Fonte |
| :--- | :--- | :--- |
| Tempo de mercado | 11 anos | entrevista |
| Pessoas | 9: 3 sócios, 1 recepcionista e 5 funcionários na execução | entrevista |
| Atendimentos | 6 a 8 por dia, cerca de 132 a 180 por mês | entrevista |
| Sistema atual | sistema antigo, com lançamento manual de serviços e sem controle de estoque | entrevista e observação |
| Formas de pagamento | todas, incluindo crédito parcelado; há pagamentos parciais | entrevista |
| Garantia | 3 meses na mão de obra; peça trazida pelo cliente sem garantia | entrevista |

## 3. O que foi dito (entrevista)

- **Fluxo de atendimento.** O cliente relata o problema. A recepção coleta os dados pessoais, a placa e a km; nesse momento o atendimento vira OS. Depois vêm o cadastro do cliente, a avaliação do veículo, o orçamento, a execução e a comunicação da data de liberação.
- **Responsáveis por etapa.** Cadastro: recepcionista. Avaliação: os três sócios. Orçamento: um ou dois sócios. Execução: mecânico.
- **Catálogo de serviços.** O serviço é escolhido numa lista com preço (troca de óleo, revisão, correia dentada…), não digitado na hora.
- **Busca.** Mais por placa; depois por nome do cliente (que traz todos os veículos dele) e por CPF.
- **Garantia e retrabalho.** Quando o cliente volta na garantia, a mesma OS é reaproveitada, sem mudar a data de entrada, e só se acrescenta uma observação.
- **Troca de dono.** Quando o veículo é vendido, o cadastro é atualizado para o novo dono.
- **Permissões.** Só o recepcionista e um dos sócios cadastram, alteram ou consultam dados no sistema.
- **Problemas relatados.** Não há controle de estoque. Não se distingue peça do cliente de peça da oficina. O sistema não gera PDF (o orçamento é enviado por captura de tela). Já houve perda de informações e veículos cadastrados errado.

## 4. O que foi observado no local

Separado do que foi dito na entrevista, o grupo **viu**:

| Observação | Impacto no modelo |
| :--- | :--- |
| As peças ficam guardadas sem contagem nem organização por item; não há etiqueta nem controle visível de quantidade. | Confirma o P1. O estoque passa a ser um livro de movimentações (`movimentacao_estoque`) com saldo calculado e estoque mínimo por peça. |
| O recepcionista digita na hora, no balcão, os dados do cliente e a placa, sem conferência. | Confirma o P3. Placa e CPF/CNPJ ficam únicos e com formato validado (UNIQUE e CHECK), e a busca começa pela placa. |

## 5. Processos típicos de oficina × o que a Fraga faz

Os processos típicos foram levantados com apoio de IA e de pesquisa (ver README, seção 6). A coluna "Na Fraga" registra o que foi confirmado na visita.

| Processo típico | Na Fraga | No modelo |
| :--- | :--- | :--- |
| Cadastro de cliente e veículo | sim (entrevista) | `cliente`, `veiculo` |
| Agendamento de serviço | não: ordem de chegada | não modelado |
| Avaliação / diagnóstico | sim | `ordem_servico.problema_relatado`, serviço "Diagnóstico eletrônico" |
| Orçamento e aprovação do cliente | sim; aprovação pelo WhatsApp ou no balcão | `orcamento.status`, `data_decisao` |
| Execução / OS | sim | `ordem_servico`, `item_servico`, `item_peca` |
| Liberação e aviso ao cliente | sim | `status = pronta`, `cliente_avisado` |
| Recebimento / pagamento parcial | sim | `pagamento` (várias linhas por OS) |
| Garantia / retrabalho | sim | `garantia_ate`, `retrabalho_garantia` |
| Cadastro de fornecedores | sim: autopeças fixas da região | `fornecedor` |
| Compra de peças | por telefone ou WhatsApp com as autopeças fixas | `compra`, `item_compra` |
| Recebimento de peças e entrada no estoque | a recepção (Nicolas) confere nota e peças | `compra.conferida`, `movimentacao_estoque` |
| Controle de estoque / estoque mínimo | não existe hoje (problema P1) | `vw_saldo_estoque`, `peca.estoque_minimo` |
| Responsáveis por etapa / alocação de mecânicos | sim | `funcionario`, `id_atendente`, `id_mecanico` |
| Emissão de nota fiscal | sim, NFS-e em toda entrega | `ordem_servico.numero_nota_fiscal` |
| Contas a pagar / caixa | não no sistema; fica com sócios e contador | não modelado |

## 6. O que mudou desde a Entrega 1

- O **ciclo de compras** (fornecedor, compra, recebimento, entrada no estoque) entrou no modelo, como apontado na correção.
- **Funcionário** virou entidade, para registrar quem atende, quem orça, quem executa e quem tem permissão.
- O **orçamento** passou a ter status de aprovação e passou a ser a condição para executar o serviço (RN02).
- **Peça do cliente** saiu do catálogo de peças e virou a origem do item usado na OS, porque não entra no estoque nem tem garantia.

## 7. Pontos confirmados depois da visita

| Pergunta | Resposta |
| :--- | :--- |
| Quem atendeu o grupo? | Nicolas (recepcionista) — (11) 95310-5009 |
| Como a oficina compra peças? | De autopeças fixas da região, por telefone ou WhatsApp |
| Quem confere as peças que chegam? | A recepção (Nicolas): nota e peças |
| Há estoque mínimo? | Só "de cabeça", sem números; o modelo propõe mínimos a validar com os sócios |
| Como o cliente aprova o orçamento? | Pelo WhatsApp ou pessoalmente no balcão |
| Há agendamento? | Não; ordem de chegada |
| Emite nota fiscal de serviço? | Sim, em toda entrega |
| Controla contas a pagar ou caixa? | Não no sistema; fica com os sócios e o contador |
| Quantos telefones por cliente? | Um |
| Metas dos indicadores? | Não há metas formais; o grupo propõe metas no README (seção 1.6) |
