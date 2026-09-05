# Guia de Configuração: Integração do GitHub no Outline Knowledge Base

Este documento explica em detalhes o propósito da integração com o **GitHub** no **Outline**, o motivo da mensagem de "integração desativada" e o passo a passo completo para provisionar e ativar o **GitHub App** no servidor.

---

## 1. Entendendo a Integração: O que ela faz (e o que NÃO faz)

Ao navegar em **Configurações > Integrações > GitHub** (`/settings/integrations/github`), o Outline apresenta a seguinte funcionalidade:

- **O que ELA FAZ (Link Unfurling e Visualização de Dados):**
  - Permite colar links de **Issues**, **Pull Requests** e **Projects V2** do GitHub em documentos do Outline.
  - O Outline converte o link em um card interativo com status em tempo real (*Aberto*, *Fechado*, *Merged*, *Draft*), autor, data, labels e descrição.
  - Suporta menções rápidas (ex: `@pull/123`, `@issue/456`).

- **O que ELA NÃO FAZ (Não é Login Social):**
  - **Atenção:** O Outline **não utiliza** essa integração para login/autenticação de usuários no sistema. O Outline gerencia login através de provedores SSO como **Google OAuth 2.0** (já configurado), OIDC ou Slack.

---

## 2. Por que a mensagem de "desativada" apareceu?

A mensagem:
> *"A integração do GitHub está desativada no momento. Defina as variáveis de ambiente associadas e reinicie o servidor para permitir a integração."*  
> *(The GitHub integration is currently disabled. Please set the associated environment variables and restart the server to enable the integration.)*

Ocorre porque o plugin de integração com o GitHub (`plugins/github`) exige que **todas as variáveis de ambiente obrigatórias** abaixo estejam presentes no arquivo `.env` do Outline:

1. `GITHUB_APP_NAME`: Nome identificador único do GitHub App.
2. `GITHUB_APP_ID`: ID numérico do GitHub App gerado pelo GitHub.
3. `GITHUB_CLIENT_ID`: Client ID OAuth do App.
4. `GITHUB_CLIENT_SECRET`: Segredo do Client OAuth.
5. `GITHUB_APP_PRIVATE_KEY`: Chave privada gerada no GitHub (`.pem`), **codificada em Base64**.
6. `GITHUB_WEBHOOK_SECRET` *(Opcional, mas recomendado)*: Segredo de validação de webhooks.

Se essas variáveis estiverem ausentes, o Outline mantém a tela desativada para evitar erros em tempo de execução.

---

## 3. Passo a Passo: Como Criar o GitHub App

A integração do Outline com o GitHub é feita através de um **GitHub App** (e não de um simples OAuth App comum).

### Passo 3.1: Acessar a Criação do GitHub App
1. Acesse o GitHub:
   - Se for na sua conta pessoal: **[GitHub Settings > Developer Settings > GitHub Apps](https://github.com/settings/apps)**.
   - Se for em uma Organização: **GitHub > Sua Organização > Settings > Developer Settings > GitHub Apps**.
2. Clique no botão **New GitHub App**.

---

### Passo 3.2: Preencher Informações Básicas
Preencha os seguintes campos no formulário:

- **GitHub App name**: Escolha um nome exclusivo (ex: `outline-devopsvanilla-poc` ou `outline-sua-empresa`).  
  *(Esse nome será o valor de `GITHUB_APP_NAME`)*.
- **Description**: (Opcional) `Integração de Link Unfurling para o Outline Wiki`.
- **Homepage URL**:
  ```text
  https://outline-cabr-poc.devopsvanilla.com.br
  ```
- **Callback URL**:
  ```text
  https://outline-cabr-poc.devopsvanilla.com.br/api/github.callback
  ```
  *(Nota: Se houver a opção "Request user authorization (OAuth) during installation", deixe marcada).*

---

### Passo 3.3: Configurar Webhooks
Na seção **Webhook**:
1. Marque a opção **Active** (se já não estiver marcada).
2. **Webhook URL**:
   ```text
   https://outline-cabr-poc.devopsvanilla.com.br/api/github.webhooks
   ```
3. **Webhook secret**: Gere uma senha/token aleatório forte.
   - No terminal Linux/WSL: `openssl rand -hex 20`
   - Salve esse valor, pois ele será usado em `GITHUB_WEBHOOK_SECRET`.

---

### Passo 3.4: Permissões do GitHub App (*Permissions*)
Defina as seguintes permissões para que o Outline consiga ler os metadados dos repositórios:

1. **Repository permissions**:
   - **Issues**: Selecione **Read-only** *(Apenas leitura)*.
   - **Pull requests**: Selecione **Read-only** *(Apenas leitura)*.
   - **Metadata**: Selecione **Read-only** *(Geralmente marcado por padrão)*.

2. **Organization permissions** *(Opcional - necessário se você utiliza GitHub Projects)*:
   - **Projects**: Selecione **Read-only**.

---

### Passo 3.5: Eventos de Webhook (*Subscribe to events*)
Na seção **Subscribe to events**, selecione os eventos abaixo para manter as integrações sincronizadas:
- [x] **Installation**
- [x] **Installation target**
- [x] **Repository**

---

### Passo 3.6: Onde o App pode ser instalado (*Where can this GitHub App be installed?*)
- Selecione **Only on this account** (ou **Any account** se você gerencia repositórios em múltiplas contas/organizações).
- Clique em **Create GitHub App**.

---

### Passo 3.7: Obter as Credenciais e Chave Privada

Após criar o app, você será redirecionado para a página de configurações dele:

1. **App ID:** Copie o número exibido em **App ID** (ex: `1234567`).
2. **Client ID:** Copie o valor exibido em **Client ID** (ex: `Iv1.xxxxxxxxxxxx`).
3. **Client Secret:**
   - Na seção **Client secrets**, clique em **Generate a new client secret**.
   - Copie o segredo gerado imediatamente.
4. **Private Key (Chave Privada):**
   - Rolar até a seção **Private keys**.
   - Clique em **Generate a private key**.
   - O navegador fará o download automático de um arquivo `.pem` (ex: `outline-devopsvanilla.2026-09-05.private-key.pem`).
   - **IMPORTANTE:** O Outline exige essa chave codificada em **Base64 (em uma única linha)**.

#### Como converter o arquivo .pem para Base64:
- **No Linux / WSL:**
  ```bash
  base64 -w 0 seu-arquivo.private-key.pem
  ```
- **No Windows PowerShell:**
  ```powershell
  [Convert]::ToBase64String([System.IO.File]::ReadAllBytes("caminho\seu-arquivo.private-key.pem"))
  ```
  *(Copie a string longa gerada sem quebras de linha).*

---

### Passo 3.8: Instalar o App na Conta/Organização
1. No menu lateral esquerdo do GitHub App, clique em **Install App**.
2. Ao lado da sua conta pessoal ou organização, clique em **Install**.
3. Selecione se deseja conceder acesso a **All repositories** (Todos os repositórios) ou **Only select repositories** (Apenas repositórios selecionados).
4. Clique em **Install**.

---

## 4. Configurar no Projeto Ansible

Abra o arquivo [`ansible/group_vars/all.yml`](file:///Ubuntu-24.04/home/devopsvanilla/_prj/devopsvanilla/tf-outline-gcp-poc/ansible/group_vars/all.yml) e preencha o bloco da integração do GitHub com as informações obtidas:

```yaml
# ==============================================================================
# Integração GitHub (Link Unfurling para Issues, PRs e Projects - ver GitHub-Integration-Setup.md)
# ==============================================================================
outline_github_app_name: "outline-devopsvanilla-poc"
outline_github_app_id: "1234567"
outline_github_client_id: "Iv1.xxxxxxxxxxxxxxxx"
outline_github_client_secret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
outline_github_app_private_key: "LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFc..."
outline_github_webhook_secret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

---

## 5. Aplicar as Alterações na VM

Para atualizar o arquivo `.env` na VM e reiniciar o serviço do Outline, você pode executar o playbook Ansible direcionado ou via ad-hoc:

### Opção A: Executar via Ansible (Recomendado)
No terminal WSL (dentro da pasta `ansible`):

```bash
ansible-playbook -i inventory.ini playbook.yml
```

### Opção B: Atualização Rápida via Ad-hoc do Ansible
Se você só deseja atualizar o template do `.env` e reiniciar o serviço:

```bash
cd ansible
ansible outline -m template -a "src=templates/outline.env.j2 dest=/opt/outline/app/.env owner=outline group=outline mode=0600" --become
ansible outline -m service -a "name=outline state=restarted" --become
```

---

## 6. Como Usar no Outline

Após reiniciar o servidor:
1. Acesse o Outline: `https://outline-cabr-poc.devopsvanilla.com.br`.
2. Vá em **Configurações > Integrações > GitHub**.
3. A mensagem de erro terá desaparecido e você verá o botão **Connect** (Conectar).
4. Clique em **Connect** e autorize a integração na sua conta do GitHub.
5. Pronto! Agora, sempre que você colar links de issues, PRs ou projetos do GitHub dentro de um documento, eles serão exibidos com pré-visualizações ricas e atualizadas.
