# tf-outline-gcp-poc

PoC (Prova de Conceito) do [Outline Knowledge Base](https://www.getoutline.com/) e do [diagrams.net (draw.io)](https://www.diagrams.net/) na Google Cloud Platform (GCP) com arquitetura enxuta e econômica (GCP Always Free Tier), provisionados com **Terraform** e configurados com **Ansible** em VMs `e2-micro`, com componentes instalados diretamente no sistema operacional (sem Docker, para máximo desempenho e menor consumo de recursos) e utilizando o **Google Cloud Storage (GCS)** como backend de arquivos.


---

## Propósito do Projeto

Este projeto demonstra como executar o Outline de forma totalmente funcional e econômica para ambientes de teste, documentação interna ou validação de arquitetura na GCP.

A implementação toma como referência técnica:
* A documentação oficial de instalação do Outline: [Hosting / Installation Methods](https://docs.getoutline.com/s/hosting/doc/installation-methods-pSvgz9j0QC).
* O projeto da comunidade referenciado pela documentação: [rjsgn/outline-terraform-ansible](https://github.com/rjsgn/outline-terraform-ansible).

### Principais Adaptações em Relação ao Projeto Base (`rjsgn`)

| Aspecto | Projeto Base (`rjsgn`) | Nossa Solução (`tf-outline-gcp-poc`) |
| :--- | :--- | :--- |
| **Custo de Infraestrutura** | Pago (~$50+/mês com Cloud SQL e Memorystore) | **$0.00 / mês** (GCP Always Free Tier) |
| **Banco e Cache** | Cloud SQL e Cloud Memorystore | **PostgreSQL e Redis nativos na VM** |
| **Backend de Arquivos** | AWS S3 | **Google Cloud Storage (GCS)** nativo via interoperabilidade S3/HMAC |
| **Credenciais Administrativas** | Exigia download de chave privada JSON com permissões amplas | **Usa a conta já autenticada na estação** via `gcloud` (Application Default Credentials - ADC) |
| **Execução de Componentes** | PM2 | **Serviço nativo `systemd`** com journalctl e limites adequados |
| **Estabilidade na `e2-micro`** | Risco alto de OOM em builds | **4 GB de Swap** configurados automaticamente e **opção de compilação no host local** |
| **Proxy Reverso** | Nginx básico | **Nginx com suporte a WebSockets** (necessário para colaboração em tempo real do Outline) |
| **Ferramenta de Diagramação** | Não inclusa | **diagrams.net (draw.io)** nativo em VM mínima `e2-micro` dedicada com Nginx |

---

## Arquitetura da Solução

```text
[ Estação de Trabalho ]
   │
   ├──> 1. Terraform (usa credencial gcloud ADC da estação)
   │        ├──> Outline:
   │        │     ├──> Bucket GCS (com política CORS para uploads pelo browser)
   │        │     ├──> Service Account dedicada + Chave HMAC (API S3 compatível)
   │        │     ├──> IP Público Estático reservado (outline-ip)
   │        │     ├──> Firewall (Portas 22, 80, 443, 3000 e ICMP)
   │        │     └──> VM Compute Engine e2-micro (Debian 12, disco pd-standard 30 GB)
   │        │
   │        └──> diagrams.net (draw.io):
   │              ├──> IP Público Estático reservado (drawio-ip)
   │              ├──> Firewall (Portas 22, 80, 443 e ICMP)
   │              └──> VM Compute Engine e2-micro (Debian 12, disco pd-standard 20 GB)
   │
   ├──> 2. (Recomendado) Build local do Outline: ./scripts/build-outline-local.sh
   │        └──> Gera ansible/files/outline-build.tar.gz
   │
   └──> 3. Ansible Automation (SSH)
            ├──> Outline VM (playbook.yml):
            │     ├──> Swap de 4 GB (/swapfile) e swappiness=10
            │     ├──> Instala Node.js 20 LTS, PostgreSQL, Redis, Nginx e Certbot
            │     ├──> Configura banco e usuário 'outline' no PostgreSQL local
            │     ├──> Transfere e descompacta os artefatos compilados (ou clona/compila na VM)
            │     ├──> Executa as migrações de banco (yarn db:migrate)
            │     ├──> Configura .env apontando para o Cloud Storage
            │     ├──> Registra e inicia o serviço systemd (outline.service)
            │     └──> Configura Nginx como Proxy Reverso (Porta 80 -> 3000 com WebSockets)
            │
            └──> diagrams.net VM (playbook-drawio.yml):
                  ├──> Swap de 2 GB (/swapfile) e swappiness=10
                  ├──> Instala Nginx, Git, Certbot e utilitários
                  ├──> Clona a aplicação web oficial do diagrams.net em /var/www/drawio
                  ├──> Configura Nginx com gzip, caching agressivo e suporte a iframe embedding
                  └──> Emite certificado SSL gratuito Let's Encrypt (HTTPS) via Certbot
```

---

## Estrutura de Arquivos

```text
.
├── README.md
├── scripts/
│   └── build-outline-local.sh        # Compilação opcional no host para acelerar o deploy
├── ansible/
│   ├── ansible.cfg                   # Configurações do Ansible
│   ├── inventory.ini.example         # Exemplo de inventário de hosts (Outline e Draw.io)
│   ├── inventory.ini                 # Inventário ativo dos servidores
│   ├── site.yml                      # Playbook mestre para deploy completo
│   ├── playbook.yml                  # Playbook de automação da VM Outline
│   ├── playbook-drawio.yml           # Playbook de automação da VM diagrams.net
│   ├── reset.yml                     # Automação de reset rápido da base do Outline
│   ├── files/
│   │   └── .gitkeep                  # Diretório para o tarball de build local
│   ├── group_vars/
│   │   ├── all.yml.example           # Exemplo de variáveis do Outline e Draw.io
│   │   └── all.yml                   # Variáveis ativas dos ambientes
│   └── templates/
│       ├── nginx-outline.conf.j2     # Template Nginx para Outline com WebSockets
│       ├── nginx-drawio.conf.j2      # Template Nginx para diagrams.net com iframe embedding
│       ├── outline.env.j2            # Template do .env com backend Cloud Storage
│       └── outline.service.j2        # Template da unidade systemd
└── terraform/
    ├── main.tf                       # Recursos GCP (Outline e diagrams.net)
    ├── outputs.tf                    # Outputs (IPs estáticos, bucket, comandos Ansible)
    ├── variables.tf                  # Variáveis com defaults
    ├── versions.tf                   # Providers e versões mínimas
    ├── terraform.tfvars.example      # Exemplo de variáveis de entrada
    └── terraform.tfvars              # Arquivo de variáveis local
```


---

## Pré-requisitos

1. **Google Cloud SDK (`gcloud`)** instalado e autenticado na sua máquina:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project SEU_PROJECT_ID
   ```
   > **Importante**: Não é necessário baixar nenhuma chave privada de Service Account administrativa. O Terraform usará o Application Default Credentials (ADC) gerado pelo comando acima.
2. **Terraform** (`>= 1.5.0`):
   ```bash
   terraform version
   ```
3. **Ansible** (`>= 2.14.0`):
   ```bash
   ansible --version
   ```
4. **Acesso SSH à VM via Google Cloud OS Login**:

   Em muitos projetos e organizações GCP, a restrição de segurança `constraints/compute.requireOsLogin` é obrigatória (o que impede desativar o OS Login ou usar metadados manuais `ssh-keys`). Por isso, a automação já provisiona a VM com `enable-oslogin = "TRUE"` por padrão:

   1. **Identifique seu usuário POSIX do OS Login**:
      ```bash
      gcloud compute os-login describe-profile --format="value(posixAccounts[0].username)"
      ```
      *(Exemplo de retorno: `devopsvanillaofficial_gmail_com`)*.

   2. **Defina esse usuário no `terraform/terraform.tfvars`**:
      ```hcl
      ssh_user = "devopsvanillaofficial_gmail_com"
      ```

   3. **Como as chaves SSH funcionam com o OS Login**:
      O OS Login vincula automaticamente suas chaves SSH cadastradas na GCP (`~/.ssh/id_rsa`, `~/.ssh/id_ed25519` ou `~/.ssh/google_compute_engine`) à VM no momento da conexão e concede permissão de `sudo` sem senha. Se precisar vincular uma nova chave:
      ```bash
      gcloud compute os-login ssh-keys add --key-file=~/.ssh/id_rsa.pub
      ```

   4. Ao rodar `terraform apply`, o output `ansible_inventory_command` já gerará o inventário configurado para esse usuário.


---

## Passo a Passo de Implantação

### Passo 1: Provisionar a Infraestrutura com Terraform

1. Acesse o diretório do Terraform:
   ```bash
   cd terraform
   ```

2. Ajuste o arquivo `terraform.tfvars` com o seu `project_id`:
   ```hcl
   project_id         = "seu-projeto-gcp"
   region             = "us-central1"
   zone               = "us-central1-a"
   bucket_name_prefix = "outline-files"
   instance_name      = "outline-vm"
   machine_type       = "e2-micro"
   boot_disk_size     = 30
   boot_disk_type     = "pd-standard"

   # Configurações para a VM do diagrams.net (draw.io)
   enable_drawio_vm   = true
   drawio_domain_name = "drawio-cabr-poc.devopsvanilla.com.br"
   ```

3. Inicialize e aplique o plano:
   ```bash
   terraform init
   terraform apply
   ```

4. Ao final, visualize os outputs gerados:
   ```bash
   terraform output instance_external_ip
   terraform output drawio_instance_external_ip
   terraform output bucket_name
   terraform output outline_storage_access_key
   terraform output -raw outline_storage_secret_key
   ```

5. Gere o arquivo de inventário do Ansible usando o comando automático gerado pelo Terraform:
   ```bash
   # Executado a partir do diretório terraform/:
   terraform output -raw ansible_inventory_command | bash
   cd ..
   ```


---

### Passo 2: (Opcional, mas Altamente Recomendado) Compilar Artefatos no Host

A VM `e2-micro` possui apenas 1 GB de RAM e CPU compartilhada. Embora o Ansible configure 4 GB de Swap para permitir compilação direta na VM, compilar no seu host de trabalho leva apenas ~1 a 2 minutos e poupa a VM:

```bash
./scripts/build-outline-local.sh
```

O script clona o Outline, executa `yarn install && yarn build` utilizando a CPU e memória da sua estação de trabalho e gera o arquivo `ansible/files/outline-build.tar.gz`. O Ansible detectará esse arquivo automaticamente e o transferirá para a VM.

> *Nota: Se você optar por não rodar este script, o playbook do Ansible clonará e compilará o Outline diretamente na VM utilizando o swapfile de 4 GB configurado.*

---

### Passo 3: Configurar e Implantar com Ansible

1. Acesse o diretório do Ansible:
   ```bash
   cd ansible
   ```

2. Crie o arquivo de variáveis `group_vars/all.yml`:
   ```bash
   cp group_vars/all.yml.example group_vars/all.yml
   ```

3. Preencha `group_vars/all.yml` com os dados do Terraform e segredos gerados:
   * **Cenário A: Usando apenas o IP público da VM**:
     - `outline_url`: `"http://<IP_PUBLICO_DA_VM>"`
     - `outline_domain`: `"_"`
     - `outline_force_https`: `"false"`
     - `enable_ssl`: `false`

   * **Cenário B: Usando um FQDN (ex: `wiki.meudominio.com`) com SSL automático**:
     - **Como funciona o fluxo de DNS**:
       1. O Terraform (Passo 1) provisiona a infraestrutura e já entrega o IP público estático fixo (`instance_external_ip`).
       2. Você cria o apontamento DNS tipo `A` no seu provedor de domínio (`wiki.meudominio.com` ➔ `IP_ESTATICO`).
       3. Aguarde alguns minutos até o DNS replicar (teste com `ping wiki.meudominio.com`).
       4. Só então execute o Ansible com `enable_ssl: true`.
     - Configure em `all.yml`:
       - `outline_url`: `"https://wiki.meudominio.com"`
       - `outline_domain`: `"wiki.meudominio.com"`
       - `outline_force_https`: `"true"`
       - `enable_ssl`: `true`
       - `certbot_email`: `"seu-email@dominio.com"`
     - O Ansible executará o **Certbot** automaticamente, validará o domínio via Nginx, emitirá o certificado SSL gratuito Let's Encrypt e ativará o HTTPS com redirecionamento automático!
     > *Dica*: Se você preferir subir o Outline primeiro via IP e só depois de dias configurar o domínio com SSL, basta rodar o playbook com `enable_ssl: false` e, quando o DNS estiver pronto, alterar para `true` e rodar `ansible-playbook playbook.yml --tags ssl`.

   * **Dados de Integração com o Google Cloud Storage**:
     - `outline_bucket_name`: output `bucket_name` do Terraform
     - `outline_bucket_region`: output `bucket_region` do Terraform
     - `outline_storage_access_key`: output `outline_storage_access_key` do Terraform
     - `outline_storage_secret_key`: output `outline_storage_secret_key` do Terraform
     - `outline_secret_key`: gere com `openssl rand -hex 32`
     - `outline_utils_secret`: gere com `openssl rand -hex 32`
     - `outline_postgres_password`: defina uma senha forte para o banco

4. Execute o playbook de acordo com a sua necessidade:

   ```bash
   # Opção 1: Configurar apenas o servidor do Outline:
   ansible-playbook -i inventory.ini playbook.yml

   # Opção 2: Configurar apenas o servidor do diagrams.net (draw.io):
   ansible-playbook -i inventory.ini playbook-drawio.yml

   # Opção 3: Configurar ambos os servidores em lote:
   ansible-playbook -i inventory.ini site.yml
   ```

O playbook do Outline (`playbook.yml`) executará:
- Configuração do Swap de 4 GB.
- Instalação do PostgreSQL, Redis, Nginx e Node.js 20 LTS.
- Criação do banco de dados e usuário do Outline.
- Implantação da aplicação em `/opt/outline/app`.
- Execução das migrações do banco (`yarn db:migrate`).
- Inicialização do serviço `outline.service` via `systemd`.
- Configuração do Nginx para receber requisições na porta 80 e encaminhar para a porta 3000 com WebSockets habilitados.

O playbook do diagrams.net (`playbook-drawio.yml`) executará:
- Configuração do Swap de 2 GB.
- Instalação do Nginx, Git, Certbot e utilitários.
- Clonagem shallow do repositório oficial do diagrams.net em `/var/www/drawio`.
- Configuração do Nginx com gzip, caching estático e suporte a iframes para o Outline.
- Emissão de SSL gratuito Let's Encrypt para o domínio configurado.


---

### Passo 4: Configurar Provedor de Autenticação (Google OAuth 2.0 - OBRIGATÓRIO)

> [!IMPORTANT]
> **Etapa Obrigatória**: Por design de segurança, o Outline **não possui tela de login por usuário/senha local**. É obrigatório habilitar um provedor de autenticação (como o Google OAuth) para que usuários consigam acessar a aplicação.
>
> Siga o guia passo a passo completo em:
> 👉 **[Google-OAuth-Setup.md](Google-OAuth-Setup.md)**

Resumo da etapa:
1. Crie o **OAuth Client ID** no Console do Google Cloud com a URL de redirecionamento autorizada:
   `https://<SEU_DOMINIO>/auth/google.callback`
2. Adicione as credenciais em `ansible/group_vars/all.yml`:
   ```yaml
   outline_google_client_id: "seu-client-id.apps.googleusercontent.com"
   outline_google_client_secret: "seu-client-secret"
   ```
3. Reexecute o playbook para aplicar:
   ```bash
   ansible-playbook playbook.yml
   ```

---

### Passo 5: Validar o Funcionamento e o Backend GCS

1. **Acessar as Aplicações**:
   - **Outline**: `https://outline-cabr-poc.devopsvanilla.com.br` (ou `http://<IP_PUBLICO_OUTLINE>`)
   - **diagrams.net (draw.io)**: `https://drawio-cabr-poc.devopsvanilla.com.br` (ou `http://<IP_PUBLICO_DRAWIO>`)

2. **Verificar Status dos Serviços nas VMs**:
   - No servidor do Outline:
     ```bash
     ssh <USUARIO>@<IP_PUBLICO_OUTLINE> "sudo systemctl status outline nginx postgresql redis-server"
     ```
   - No servidor do diagrams.net (draw.io):
     ```bash
     ssh <USUARIO>@<IP_PUBLICO_DRAWIO> "sudo systemctl status nginx"
     ```

3. **Verificar Logs da Aplicação Outline**:
   ```bash
   ssh <USUARIO>@<IP_PUBLICO_OUTLINE> "sudo journalctl -u outline -f"
   ```


4. **Validar Armazenamento no Cloud Storage**:
   - Conclua a configuração inicial do Outline na interface web.
   - Faça upload de uma imagem ou documento como anexo.
   - Verifique os arquivos armazenados no bucket da GCP:
     ```bash
     gcloud storage ls gs://$(terraform -chdir=terraform output -raw bucket_name)/**
     ```

---

### Passo 6: Primeiro Acesso, Convites e Reset da PoC

Para orientações sobre permissões de acesso (contas Google Workspace vs. contas Gmail), auto-join de domínios corporativos e gerenciamento de membros:
👉 **[outline-inicial-setup.md](outline-inicial-setup.md)**

Para habilitar a integração com o GitHub (Link Unfurling de Issues, Pull Requests e Projects nos documentos):
👉 **[GitHub-Integration-Setup.md](GitHub-Integration-Setup.md)**


Caso precise reiniciar os dados da PoC do zero e re-provisionar o Workspace de forma 100% automatizada a qualquer momento:
```bash
cd ansible
ansible-playbook -i inventory.ini reset.yml
```

---

## Como Funciona o Armazenamento no Cloud Storage (S3 Interoperability)

O Outline utiliza internamente o cliente de armazenamento compatível com S3 (`FILE_STORAGE=s3`). Para integrar de forma nativa e transparente com o Google Cloud Storage sem exigir provedores externos:

1. O Terraform cria uma **Service Account** dedicada com papel `roles/storage.objectAdmin` no bucket GCS.
2. O Terraform ativa a **Chave HMAC** para essa Service Account através do recurso `google_storage_hmac_key`.
3. O template `.env` do Outline é configurado com:
   ```dotenv
   FILE_STORAGE=s3
   AWS_ACCESS_KEY_ID="<HMAC_ACCESS_ID>"
   AWS_SECRET_ACCESS_KEY="<HMAC_SECRET>"
   AWS_REGION="us-central1"
   AWS_S3_UPLOAD_BUCKET_NAME="<NOME_DO_BUCKET_GCS>"
   AWS_S3_UPLOAD_BUCKET_URL="https://storage.googleapis.com"
   AWS_S3_FORCE_PATH_STYLE=true
   ```
4. O bucket GCS é provisionado com política **CORS** que permite verbos `GET`, `PUT`, `POST` e cabeçalhos abertos para possibilitar uploads diretos do navegador via presigned URLs.

---

## Provisionamento e Uso do diagrams.net (draw.io)

O projeto inclui uma automação completa para provisionar uma VM mínima (`e2-micro`, Debian 12, 20 GB de disco) executando o **diagrams.net (draw.io)** instalado diretamente no sistema operacional (sem Docker para máximo desempenho e menor consumo de recursos), servido pelo **Nginx** com compressão gzip, cache de assets e emissão automática de certificado SSL gratuito com **Certbot / Let's Encrypt**.

### 1. Provisionar a VM com Terraform
No arquivo `terraform/terraform.tfvars`:
```hcl
enable_drawio_vm   = true
drawio_domain_name = "drawio-cabr-poc.devopsvanilla.com.br"
```

Aplique a infraestrutura:
```bash
cd terraform
terraform apply
```

O Terraform exibirá o output `drawio_instance_external_ip` com o IP público estático fixo da nova VM e atualizará `ansible_inventory_command` para registrar tanto a VM do Outline quanto a do diagrams.net em `ansible/inventory.ini`.

### 2. Configuração do DNS
Crie um apontamento DNS do tipo `A` no seu provedor de domínio apontando para o IP público estático retornado pelo Terraform:
```text
drawio-cabr-poc.devopsvanilla.com.br  IN  A  <IP_PUBLICO_DRAWIO>
```

### 3. Executar o Playbook do diagrams.net
Verifique as variáveis no arquivo `ansible/group_vars/all.yml`:
```yaml
drawio_domain: "drawio-cabr-poc.devopsvanilla.com.br"
drawio_enable_ssl: true
drawio_certbot_email: "sandro@devopsvanilla.com.br"
```

Execute o playbook dedicado para configurar a VM do diagrams.net:
```bash
cd ansible
ansible-playbook -i inventory.ini playbook-drawio.yml
```

> **Dica**: Se quiser implantar tanto o Outline quanto o diagrams.net em um único comando, execute o playbook mestre:
> ```bash
> ansible-playbook -i inventory.ini site.yml
> ```

### 4. Como Integrar e Embutir Diagramas no Outline

O Nginx do diagrams.net foi configurado com cabeçalhos de segurança (`Content-Security-Policy: frame-ancestors`) que permitem que seus diagramas sejam embutidos diretamente no Outline:

1. **Via Iframe / Embed no Outline**:
   Em qualquer documento do Outline, digite `/embed` ou insira um iframe apontando para o seu diagrams.net:
   ```html
   <iframe src="https://drawio-cabr-poc.devopsvanilla.com.br/?embed=1&ui=min" width="100%" height="600" frameborder="0"></iframe>
   ```

2. **Via Exportação de Imagem com Dados XML Embutidos**:
   No diagrams.net, ao exportar seu diagrama como **PNG** ou **SVG**, mantenha marcada a opção **"Include a copy of my diagram"**. Cole a imagem diretamente no Outline. Se precisar editar o diagrama no futuro, basta arrastar a imagem de volta para o editor do diagrams.net!

---

## Descomissionamento (Limpeza de Recursos)

Para destruir todos os recursos criados na GCP e evitar qualquer cobrança futura:

```bash
cd terraform
terraform destroy
```

