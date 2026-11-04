# Manual do Sistema da Oficina Fraga

Guia rápido para quem atende no balcão. Não precisa saber nada de banco de dados.

## Abrir e fechar

- **Abrir:** dois cliques no ícone **Sistema Oficina Fraga** da Área de Trabalho. Uma janela preta aparece e, em seguida, o sistema abre no navegador.
- **Usar:** deixe a janela preta aberta (pode minimizar) enquanto trabalha.
- **Fechar:** feche a janela preta. O sistema e o banco desligam juntos, e tudo o que foi lançado fica salvo.
- **Se fechou o navegador sem querer:** abra o endereço **http://127.0.0.1:8780** ou clique no ícone de novo.

## O dia a dia

### 1. Chegou um carro

Digite a **placa** na busca lá em cima e clique em **Buscar**.

- **O carro já veio antes:** abre a ficha dele com o histórico. Clique em **Abrir ordem de serviço**.
- **É a primeira vez:** clique em **Cadastrar cliente e carro**, preencha e salve.
  - O CPF e o CEP podem ser digitados só com números.
  - A placa pode ter traço ou letras minúsculas: o sistema arruma.
- **O dono já é cliente, mas o carro é novo:** vá em **Clientes**, abra o cliente e use **Adicionar outro carro**.

### 2. Abrir a ordem de serviço (OS)

Escreva o que o cliente relatou, a km do painel e a previsão de entrega, e escolha quem está atendendo. O número da OS sai sozinho.

### 3. Montar o orçamento

Na OS, adicione os **serviços** (o preço do catálogo aparece e pode ser mudado) e as **peças**.

- A lista de peças mostra quanto tem no estoque de cada uma.
- Se o cliente **trouxe a peça**, escolha "Peça trazida pelo cliente" (no fim da lista) e escreva qual é. Ela não é cobrada e não tem garantia.

Quando terminar, escolha quem fez o orçamento e clique em **Enviar orçamento ao cliente**. A partir daí os itens ficam travados: o valor aprovado é o valor cobrado.

### 4. O cliente respondeu

- **Aprovou:** escolha o mecânico e clique em **Sim, aprovou**. As peças saem do estoque automaticamente.
- **Recusou:** clique em **Cliente recusou**. A OS fica cancelada.

### 5. Serviço terminado

Clique em **Marcar como pronto**, avise o cliente (o telefone aparece na tela) e clique em **Já avisei**.

### 6. Receber

Em **Receber pagamento**, informe o valor, a forma (Pix, dinheiro, débito ou crédito) e as parcelas, se for no crédito.

- Pode receber em partes: uma entrada agora e o resto na retirada.
- A tela sempre mostra quanto **falta pagar**.

### 7. Entregar o carro

Confira o número da nota fiscal e clique em **Entregar o carro**. A garantia da mão de obra (3 meses) é calculada sozinha. Se ainda faltar dinheiro, o carro pode ser entregue mesmo assim: o valor fica em "a receber".

## Tela inicial

- **Cartões no topo:** carros na oficina, prontos para retirar, entradas do dia, quanto há a receber e quantas peças estão abaixo do mínimo. Clicar nos dois últimos abre o relatório correspondente.
- **Lista "Carros na oficina agora":** os prontos aparecem primeiro. Se aparecer "avisar cliente", o carro está pronto e ninguém avisou ainda.

## Relatórios

Em **Relatórios**, clique numa pergunta para ver a resposta com os dados do dia:

- peças para comprar;
- faturamento do mês;
- ticket médio;
- serviços mais feitos;
- quem está devendo.

Em **Conferência dos dados**, se a resposta for "Nenhum problema encontrado", está tudo certo.

## Se algo der errado

| Mensagem | O que fazer |
| :--- | :--- |
| "Já existe um carro cadastrado com essa placa" | Busque a placa: o carro já está no sistema. |
| "Não há peças suficientes no estoque" | Compre a peça ou troque por outra antes de aprovar. |
| "O banco de dados está desligado" | Feche a janela preta e abra pelo ícone de novo. |
| A página não abre | Confira se a janela preta está aberta; se não estiver, clique no ícone. |

## Para o suporte (técnico)

- Banco MySQL portátil em `127.0.0.1:3307` (pastas configuradas no início do `abrir-sistema.bat`).
- Sistema em Node.js (`server.js`), porta 8780, acessível só neste computador.
- Na primeira vez, o `abrir-sistema.bat` cria o banco a partir do `docs/script.sql` (com os dados de exemplo) e instala as dependências (`npm install`).
- Para criar o ícone em outro computador: botão direito em `criar-atalho.ps1` → "Executar com o PowerShell".
- Os relatórios são lidos das consultas G01–G12 e A01–A10 do `docs/script.sql` (na raiz do repositório): se o script mudar, os relatórios acompanham.
- **Para uso real:** apagar os dados de exemplo, definir uma senha para o MySQL e fazer cópia de segurança diária da pasta de dados.
