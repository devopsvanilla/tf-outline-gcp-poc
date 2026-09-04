# tf-outline-gcp-poc

PoC do Outline na GCP provisionado com Terraform e configurado com Ansible em uma VM `e2-micro` (free tier), usando Cloud Storage como backend de arquivos.

## Estrutura

```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── group_vars/all.yml.example
│   ├── inventory.ini.example
│   ├── playbook.yml
│   └── templates/
│       ├── outline.env.j2
│       └── outline.service.j2
└── terraform/
    ├── main.tf
    ├── outputs.tf
    ├── variables.tf
    └── versions.tf
```

## Pré-requisitos

- Projeto GCP com billing habilitado
- `terraform >= 1.5`
- `ansible >= 2.14`
- Acesso SSH à VM
- Uma chave JSON de service account com acesso ao bucket

## Passo 1: provisionar a infraestrutura com Terraform

O Terraform cria:

- provider `google`
- bucket do Cloud Storage
- service account para o Outline
- VM `e2-micro`
- firewall liberando SSH (`22`) e Outline (`3000`)
- outputs com IP externo, nome do bucket e e-mail da service account

### 1.1. Exemplo de variáveis

Crie um arquivo `terraform/terraform.tfvars` localmente:

```hcl
project_id                  = "meu-projeto-gcp"
region                      = "us-central1"
zone                        = "us-central1-a"
bucket_name_prefix          = "outline-poc"
instance_name               = "outline-vm"
credentials_file            = "/caminho/para/minha-chave-admin.json"
ssh_source_ranges           = ["0.0.0.0/0"]
outline_source_ranges       = ["0.0.0.0/0"]
```

### 1.2. Inicializar e aplicar

```bash
cd terraform
terraform init
terraform apply
```

### 1.3. Outputs esperados

```bash
terraform output instance_external_ip
terraform output bucket_name
terraform output outline_service_account_email
```

### 1.4. Gerar a chave JSON da service account do bucket

Depois do `apply`, gere a chave localmente para usar no Ansible:

```bash
gcloud iam service-accounts keys create outline-storage-key.json \
  --iam-account "$(terraform output -raw outline_service_account_email)"
```

## Passo 2: configurar a VM com Ansible

O playbook faz:

- instalação de pacotes básicos (`Node.js`, `npm`, `Yarn`, `Git`)
- instalação e habilitação de PostgreSQL e Redis
- criação do usuário e database do Outline no PostgreSQL
- clone do repositório do Outline
- instalação de dependências com `yarn`
- geração do `.env`
- build da aplicação
- criação de um serviço `systemd` para o Outline

### 2.1. Inventário

Copie `ansible/inventory.ini.example` para `ansible/inventory.ini` e ajuste o IP:

```ini
[outline]
outline-vm ansible_host=203.0.113.10 ansible_user=debian
```

### 2.2. Variáveis

Copie `ansible/group_vars/all.yml.example` para `ansible/group_vars/all.yml` e preencha os valores reais:

```yaml
outline_bucket_name: "outline-poc-abc123"
outline_secret_key: "gere-um-secret-key-forte"
outline_utils_secret: "gere-um-utils-secret-forte"
outline_postgres_password: "troque-esta-senha"
outline_google_credentials_json: |
  {
    "type": "service_account",
    "project_id": "meu-projeto-gcp"
  }
```

> Use Ansible Vault para proteger `outline_google_credentials_json`, `outline_secret_key`, `outline_utils_secret` e `outline_postgres_password`.

### 2.3. Executar o playbook

```bash
cd ansible
ansible-playbook playbook.yml
```

## Variáveis de ambiente geradas para o Outline

O template `.env` inclui os campos principais pedidos neste roteiro:

```dotenv
DATABASE_URL=postgres://outline:<senha>@127.0.0.1:5432/outline
REDIS_URL=redis://127.0.0.1:6379
GOOGLE_APPLICATION_CREDENTIALS=/etc/outline/gcp-service-account.json
BUCKET_NAME=<nome-do-bucket>
SECRET_KEY=<secret>
UTILS_SECRET=<utils-secret>
```

## Passo 3: validar o backend no Cloud Storage

1. Acesse `http://<IP-EXTERNO>:3000`
2. Finalize a configuração do Outline
3. Faça upload de um arquivo pela interface
4. Confirme o objeto no bucket:

```bash
gcloud storage ls gs://$(terraform -chdir=terraform output -raw bucket_name)
```

## Observações

- O playbook grava a chave JSON em `/etc/outline/gcp-service-account.json` com permissão `0600`
- O serviço da aplicação sobe via `systemd` com `yarn start`
- Ajuste `outline_allowed_hosts` e `outline_url` se quiser expor o serviço atrás de domínio, proxy ou HTTPS
