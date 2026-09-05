# Guia de Inicialização e Reset do Outline Knowledge Base

Este documento detalha o funcionamento da autenticação, o fluxo de inicialização do espaço de trabalho, como convidar usuários (Google Workspace e Gmail) e como utilizar o playbook de reset automatizado.

---

## 1. Usuários de Google Workspace e Gmail podem usar o espaço?

**SIM, ambos podem utilizar o Outline com total suporte ao Google OAuth 2.0!** Porém, devido às políticas de segurança do Outline, há uma pequena diferença na forma como cada tipo de conta ingressa no workspace:

### A. Usuários do Google Workspace (E-mails Corporativos)
*Exemplo: `colaborador@devopsvanilla.com.br` ou `usuario@suaempresa.com`*

* **Entrada Automática (Auto-join):**
  1. No painel do Outline, acesse **Settings** (*Configurações*) > **Authentication** (*Autenticação*).
  2. No campo **Allowed Domains** (*Domínios Permitidos*), adicione o domínio da sua empresa (ex: `devopsvanilla.com.br`).
  3. A partir desse momento, qualquer colaborador com uma conta desse Google Workspace que acessar a URL do Outline e clicar em **Continue with Google** entrará diretamente no workspace, com provisionamento automático de conta! Não é necessário enviar convites um a um.

### B. Usuários com Gmail Pessoal (`@gmail.com`)
*Exemplo: `usuario@gmail.com`*

* **Entrada por Convite Prévio:**
  * O Outline possui uma proteção intencional de código (`GmailAccountCreationError`): ele impede que contas públicas `@gmail.com` desconhecidas criem ou se auto-cadastrem em espaços de trabalho sem autorização prévia.
  * Para permitir que uma conta `@gmail.com` use o espaço:
    1. O Administrador acessa **Settings** (*Configurações*) > **Members** (*Membros*).
    2. Clica em **Invite people** (*Convidar pessoas*).
    3. Digita o e-mail `@gmail.com` do usuário e seleciona a permissão (*Member* ou *Admin*).
    4. O usuário receberá um convite por e-mail (via SMTP do Gmail configurado) OU poderá simplesmente acessar a URL do Outline e clicar em **Continue with Google** usando aquela conta Gmail. Como o e-mail já existe na lista do time, o Outline autoriza o login imediatamente!

> [!TIP]
> **Configuração da Tela de Consentimento no GCP Console:**
> - Se você selecionou **Internal** na tela de consentimento OAuth do Google Cloud, apenas contas do seu Google Workspace organizacional conseguirão fazer login.
> - Se você selecionou **External** (Externo), tanto contas do Google Workspace quanto contas pessoais `@gmail.com` conseguirão se autenticar. Em modo *Testing*, certifique-se de adicionar os e-mails na lista de **Test Users** do GCP Console, ou clique em **Publish App** para aceitar qualquer conta convidada.

---

## 2. Playbook de Reset Automatizado (`ansible/reset.yml`)

Foi criado um playbook dedicado para resetar completamente o Outline sempre que necessário. O playbook realiza de forma segura:
1. Confirmação de segurança (evita execução acidental).
2. Interrupção controlada do serviço `outline.service`.
3. Limpeza total do banco de dados PostgreSQL (`outline`).
4. Limpeza de cache e sessões no Redis (`redis-cli flushall`).
5. Execução de todas as migrações do banco (`yarn db:migrate`).
6. Provisionamento automático ou manual do espaço de trabalho.

### Modo 1: Reset com Provisionamento Automático (Padrão)

Este modo limpa a base e já provisiona o Workspace e o Administrador imediatamente via API local, deixando o Google OAuth 100% ativo e pronto para você logar com 1 clique.

Execute no seu terminal WSL:
```bash
cd /home/devopsvanilla/_prj/devopsvanilla/tf-outline-gcp-poc/ansible
ansible-playbook -i inventory.ini reset.yml
```
O playbook solicitará confirmação digitando `yes`.

Para rodar de forma não-interativa (ex: em scripts):
```bash
ansible-playbook -i inventory.ini reset.yml -e "confirm=yes"
```

Para customizar o nome do time ou os dados do administrador no momento do reset:
```bash
ansible-playbook -i inventory.ini reset.yml \
  -e "workspace_name='Cloud Ace Brasil' admin_name='Sandro Cicero' admin_email='devopsvanillaofficial@gmail.com' confirm=yes"
```

*Após a conclusão, basta acessar `https://outline-cabr-poc.devopsvanilla.com.br` e clicar em **Continue with Google** com a conta `devopsvanillaofficial@gmail.com` para entrar diretamente como Administrador.*

---

### Modo 2: Reset para o Assistente Web (Modo Wizard)

Se você preferir que o Outline volte à tela inicial de instalação no navegador (formulário de boas-vindas para digitar nome e e-mail manualmente):

```bash
cd /home/devopsvanilla/_prj/devopsvanilla/tf-outline-gcp-poc/ansible
ansible-playbook -i inventory.ini reset.yml -e "wizard=true confirm=yes"
```

O playbook irá:
1. Resetar PostgreSQL e Redis.
2. Comentar temporariamente as credenciais do Google OAuth no `.env`.
3. Reiniciar o Outline na tela de configuração inicial.
4. Você abre `https://outline-cabr-poc.devopsvanilla.com.br`, preenche o formulário web e cria o workspace.
5. Após criar o workspace, reative o Google OAuth rodando o playbook principal:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

---

## 3. Variáveis de Configuração Padrão (`ansible/group_vars/all.yml`)

Os dados do workspace utilizados pelo playbook de reset ficam centralizados em `ansible/group_vars/all.yml`:

```yaml
# ==============================================================================
# Dados do Workspace Inicial (utilizados na automação de reset.yml)
# ==============================================================================
initial_workspace_name: "Cloud Ace Brasil"
initial_admin_name: "Sandro Cicero"
initial_admin_email: "devopsvanillaofficial@gmail.com"

# Envio de E-mails / SMTP (notificações e convites)
outline_smtp_host: "smtp.gmail.com"
outline_smtp_port: 587
outline_smtp_secure: false
outline_smtp_username: "devopsvanillaofficial@gmail.com"
outline_smtp_password: "sua-senha-de-app"
outline_smtp_from_email: "devopsvanillaofficial@gmail.com"
```

---

## 4. Testando Uploads no Google Cloud Storage (GCS)

Após acessar o workspace:
1. Crie uma nova coleção clicando em **+ New collection**.
2. Abra um documento e clique em **New doc**.
3. Arraste uma imagem (`.png`, `.jpg`) ou arquivo para o editor.
4. O Outline realizará o upload seguro direto para o bucket GCS via interoperabilidade S3 (HMAC).
5. Confirme o arquivo no bucket pelo terminal:
   ```bash
   gcloud storage ls gs://$(terraform -chdir=terraform output -raw bucket_name)/**
   ```
