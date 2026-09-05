# Guia de Configuração: Google OAuth 2.0 para o Outline na GCP

Este documento fornece o passo a passo completo para provisionar e configurar as credenciais do **Google OAuth 2.0** no Google Cloud Platform (GCP) para autenticação de usuários no **Outline Knowledge Base**.

---

## 1. Por que esta etapa é obrigatória?

O Outline adota uma arquitetura focada em segurança corporativa e **não possui sistema de autenticação local por senha armazenada em banco de dados**. 

Para que qualquer usuário (inclusive o administrador) consiga acessar a aplicação e criar/gerenciar documentos, é obrigatório habilitar pelo menos um provedor de identidade (**SSO**). O **Google OAuth** é a opção natural e recomendada para deploys na GCP:
- **Custo:** **100% Gratuito** (não consome créditos, não exige plano pago).
- **Sem senhas locais:** O Outline delega a autenticação para a infraestrutura de segurança do Google.
- **Não automatizável via Terraform:** O Google restringe a criação do OAuth Web Client e Consent Screen exclusivamente à interface web (*Google Cloud Console*) por motivos de proteção contra phishing e abuso.

---

## 2. Passo a Passo no Google Cloud Console

Execute os passos abaixo logado na mesma conta Google que possui acesso ao projeto GCP (ex: `poc-terraform-ansible`):

### Passo 2.1: Configurar a Tela de Consentimento OAuth (*OAuth consent screen*)

1. Acesse: **[Google Cloud Console > APIs & Services > OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)**.
2. Certifique-se de que o projeto correto está selecionado na barra superior do Console.
3. Escolha o **User Type** (*Tipo de Usuário*):
   - **Internal (Interno):** Se você utiliza **Google Workspace** (domínio corporativo próprio, ex: `@devopsvanilla.com.br`).
     > *Vantagem*: Qualquer pessoa da sua organização poderá fazer login imediatamente, sem telas de aviso e sem necessidade de aprovação do Google.
   - **External (Externo):** Se você pretende permitir login de contas pessoais `@gmail.com` ou de múltiplos domínios.
4. Clique em **CREATE**.
5. Preencha as informações do aplicativo:
   - **App name**: `Outline Wiki`
   - **User support email**: Selecione seu e-mail.
   - **App logo** *(Opcional)*: Pode deixar em branco.
   - **Authorized domains**: Adicione o domínio raiz:
     ```text
     devopsvanilla.com.br
     ```
   - **Developer contact information**: Seu e-mail de contato.
6. Clique em **SAVE AND CONTINUE**.
7. Na etapa **Scopes** (*Escopos*):
   - O Outline necessita apenas dos escopos básicos de perfil (`openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`).
   - Clique em **ADD OR REMOVE SCOPES**, selecione esses 3 escopos básicos e clique em **UPDATE**.
   - Clique em **SAVE AND CONTINUE**.
8. Na etapa **Test users** (*Usuários de teste* — visível apenas no modo *External*):
   - Como o app estará em modo de teste, adicione os e-mails `@gmail.com` que terão permissão de fazer login.
   - Clique em **SAVE AND CONTINUE**.
9. Clique em **BACK TO DASHBOARD**.

---

### Passo 2.2: Criar as Credenciais OAuth 2.0 (Client ID e Secret)

1. No menu lateral esquerdo, acesse **[Credentials](https://console.cloud.google.com/apis/credentials)**.
2. No menu superior, clique em **+ CREATE CREDENTIALS** e selecione **OAuth client ID**.
3. Em **Application type**, selecione: **Web application**.
4. Em **Name**, defina um identificador, ex: `Outline Web Client`.
5. Em **Authorized JavaScript origins** (*Origens JavaScript autorizadas*):
   - Clique em **+ ADD URI** e insira a URL base HTTPS da sua aplicação:
     ```text
     https://outline-cabr-poc.devopsvanilla.com.br
     ```
6. Em **Authorized redirect URIs** (*URIs de redirecionamento autorizados*):
   - Clique em **+ ADD URI** e insira exatamente a URL de callback do Outline:
     ```text
     https://outline-cabr-poc.devopsvanilla.com.br/auth/google.callback
     ```
   > ⚠️ **Importante**: Certifique-se de incluir o protocolo `https://` e o caminho exato `/auth/google.callback`. Sem isso, o Google rejeitará o login com erro `redirect_uri_mismatch`.

7. Clique em **CREATE**.
8. Uma janela modal será exibida com as credenciais geradas:
   - **Your Client ID**: uma sequência terminada em `.apps.googleusercontent.com`
   - **Your Client Secret**: uma sequência iniciada em `GOCSPX-...`
   - Copie ambos os valores.

---

## 3. Configurar as Credenciais no Ansible

1. Abra o arquivo de variáveis do Ansible na sua estação de trabalho:
   [ansible/group_vars/all.yml](file:///wsl.localhost/Ubuntu-24.04/home/devopsvanilla/_prj/devopsvanilla/tf-outline-gcp-poc/ansible/group_vars/all.yml)

2. Adicione as duas variáveis com os valores obtidos no Console:
   ```yaml
   # Credenciais do Google OAuth 2.0 para Login
   outline_google_client_id: "SEU_CLIENT_ID_AQUI.apps.googleusercontent.com"
   outline_google_client_secret: "SEU_CLIENT_SECRET_AQUI"
   ```

3. Execute o playbook do Ansible para aplicar as novas configurações na VM:
   ```bash
   cd /home/devopsvanilla/_prj/devopsvanilla/tf-outline-gcp-poc/ansible
   ansible-playbook playbook.yml
   ```

---

## 4. O que o Ansible faz nos bastidores?

Ao executar o playbook, o Ansible realiza automaticamente:
1. Atualiza o arquivo `/opt/outline/app/.env` na VM incluindo as variáveis:
   ```dotenv
   GOOGLE_CLIENT_ID="<seu_client_id>"
   GOOGLE_CLIENT_SECRET="<seu_client_secret>"
   ```
2. Reinicia o serviço `outline.service` via systemd.
3. O Outline detecta o plugin do Google ativo e registra o provedor de autenticação no banco de dados e na rota `/api/auth.config`.

---

## 5. Validação do Login

1. Abra a URL no seu navegador:
   👉 **[https://outline-cabr-poc.devopsvanilla.com.br](https://outline-cabr-poc.devopsvanilla.com.br)**
2. A tela de login do Outline agora exibirá o botão oficial:
   ```text
   [ Continue with Google ]
   ```
3. Clique no botão. Você será redirecionado para a tela de consentimento da Google, selecionará sua conta e retornará autenticado no painel do Outline como Administrador!
