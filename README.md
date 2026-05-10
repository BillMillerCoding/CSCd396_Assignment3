# CSCD 396 – Assignment 3

A mono-repo containing all code and infrastructure for Assignment 3 of EWU CSCD 396 (Fall 2023).

---

## Repository Layout

```
.
├── .github/
│   └── workflows/
│       ├── deploy-app.yml   # CI/CD – deploy application code
│       └── deploy-iac.yml   # CI/CD – deploy Terraform infrastructure (then redeploys app)
├── iac/                     # Terraform infrastructure-as-code
│   ├── backend.tf           # Remote state backend (Azure Storage)
│   ├── main.tf              # All Azure resources
│   ├── variables.tf
│   └── outputs.tf
└── src/
    ├── WebApp/              # ASP.NET Core 8 container app (Assignment 2 feature extended)
    │   ├── Controllers/
    │   ├── Models/
    │   ├── Views/
    │   ├── Dockerfile
    │   └── WebApp.csproj
    └── FunctionApp/         # Azure Function (Service Bus → Blob Storage)
        ├── ServiceBusMessageFunction.cs
        ├── Program.cs
        ├── host.json
        └── FunctionApp.csproj
```

---

## Part 1 – Azure Function: Service Bus → Blob Storage

The `FunctionApp` project contains a single Azure Function (`ServiceBusMessageFunction`) that:

1. Is **triggered** by messages arriving on an Azure Service Bus queue.
2. **Writes** the message body as a text blob to an Azure Storage Account container.

### Managed Identity Setup (Terraform)

| Resource | Role | Scope |
|---|---|---|
| Function App (System Assigned MI) | **Storage Blob Data Contributor** | Messages Storage Account |
| Function App (System Assigned MI) | **Azure Service Bus Data Receiver** | Service Bus Namespace |

No connection strings are stored. Authentication uses `DefaultAzureCredential` which resolves to the Managed Identity automatically in Azure.

### Required App Settings (set by Terraform)

| Setting | Description |
|---|---|
| `SERVICEBUS_QUEUE_NAME` | Name of the Service Bus queue |
| `ServiceBusConnection__fullyQualifiedNamespace` | Service Bus namespace FQDN (passwordless auth) |
| `STORAGE_ACCOUNT_NAME` | Storage Account name for writing blobs |
| `STORAGE_CONTAINER_NAME` | Blob container name (default: `messages`) |

---

## Part 2 – Web App: Send Messages to Service Bus

The `WebApp` project is an ASP.NET Core 8 MVC application that:

1. Presents a **text box** and **Submit button** for entering messages.
2. On submit, sends the message to the Azure Service Bus queue using the **Azure SDK for .NET** (`Azure.Messaging.ServiceBus`).
3. Displays a success/failure notification.

The app is containerized via a multi-stage `Dockerfile` and hosted as an **Azure Container App**.

### Managed Identity Setup (Terraform)

| Resource | Role | Scope |
|---|---|---|
| Container App (System Assigned MI) | **Azure Service Bus Data Sender** | Service Bus Namespace |
| Container App (System Assigned MI) | **AcrPull** | Azure Container Registry |

### Required Environment Variables (set by Terraform / Container App)

| Variable | Description |
|---|---|
| `SERVICEBUS_NAMESPACE` | Fully-qualified Service Bus namespace (e.g. `mynamespace.servicebus.windows.net`) |
| `SERVICEBUS_QUEUE_NAME` | Name of the Service Bus queue |

---

## Part 3 – GitHub Actions CI/CD Triggering Strategy

### How triggers work

| What changes | Workflow triggered | What happens |
|---|---|---|
| `src/WebApp/**` or `src/FunctionApp/**` | `deploy-app.yml` | Builds Docker image → pushes to ACR → updates Container App → publishes & deploys Function App |
| `iac/**` | `deploy-iac.yml` | Runs `terraform init/validate/plan/apply` → **then calls `deploy-app.yml`** to redeploy application code |

This means:
- Application code changes **only** deploy application code.
- Terraform code changes **only** deploy infrastructure **and then** redeploy the application to pick up any infrastructure changes.
- They do not overlap: path filters on `push` ensure each workflow fires for its own set of changes.

The redeployment after Terraform is achieved using GitHub Actions [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows): `deploy-iac.yml` calls `deploy-app.yml` via `workflow_call` in its `redeploy-app` job.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Client ID of the Azure AD service principal / federated identity |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name holding Terraform state |
| `TF_STATE_RESOURCE_GROUP` | Resource group containing the Terraform state storage account |

### Required GitHub Variables (`vars.*`)

| Variable | Description |
|---|---|
| `ACR_NAME` | Azure Container Registry name (without `.azurecr.io`) |
| `CONTAINER_APP_NAME` | Azure Container App name |
| `RESOURCE_GROUP` | Azure Resource Group name |
| `FUNCTION_APP_NAME` | Azure Function App name |

---

## Getting Started (First-Time Setup)

1. **Create the Terraform state storage account** (one-time, manual):
   ```bash
   az group create -n rg-tfstate -l eastus
   az storage account create -n <state-storage-name> -g rg-tfstate --sku Standard_LRS
   az storage container create -n tfstate --account-name <state-storage-name>
   ```

2. **Update `iac/backend.tf`** with your `storage_account_name`.

3. **Create a federated credential** for GitHub Actions OIDC authentication on your Azure AD app registration or managed identity, and set the GitHub secrets listed above.

4. **Push to `main`** — the workflows will take care of the rest.

---

## Azure Resource Group

> **TODO:** Add the Azure Portal link to your resource group here after first deployment.

## Contributor Access

> jcurry9@ewu.edu has been added as a Contributor on the Azure subscription.