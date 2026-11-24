# Apigee X Vendor Estate Provisioning

This Terraform module provisions an isolated, multi-tenant [Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/what-is-apigee) vendor environment in Google Cloud. It establishes a dedicated VPC with Private Service Access (PSA), provisions an Apigee Organization and Runtime Instance, and exposes ingress traffic through an External HTTPS Load Balancer with Private Service Connect (PSC) Network Endpoint Groups (NEGs).

---

## How It Works

```
[ External Client ] 
        │
        ▼ (HTTPS :443)
[ Global External Load Balancer (IP / Cert / URL Map) ]
        │
        ▼
[ Regional PSC NEG ] ──(Private Service Connect)──► [ Apigee Runtime Instance (Managed VPC) ]
                                                                │
                                                    (Private Service Access /22)
                                                                ▼
                                                    [ Vendor VPC Network ]
```

1. **Network Layer:** Creates a dedicated VPC (`apigee-<vendor_slug>`) and provisions a Service Networking Connection via Private Service Access (PSA) using reserved private IP space.
2. **Apigee Management & Runtime:** Deploys a Cloud PAYG Apigee Organization, attaches a regional runtime instance, and configures an Environment (`prod`) with an associated Environment Group.
3. **Ingress Load Balancing:** Allocates an external static IPv4 address and creates an External Managed HTTP(S) Load Balancer. The backend targets the Apigee instance's service attachment through a regional PSC Network Endpoint Group (NEG).
4. **DNS & Certificate Routing Patterns:**
   * **Pattern I (External DNS):** Operator manages DNS externally. Supports a two-step apply using `defer_cert = true` to allocate the LB IP first, allowing DNS propagation before generating Google-managed certificates.
   * **Pattern III (Self-Managed Cloud DNS):** When `dns_managed_by_us = true`, the module automatically creates a delegated Cloud DNS managed subzone and provisioned `A` record pointing to the LB IP.
5. **IAM Boundaries:** Creates a per-vendor Provisioner Service Account (`provisioner-<vendor_slug>`) to bound deployment blast radius, grants `roles/apigee.admin` to specified operator identities, and provisions a downstream proxy deployment Service Account (`proxy-deployer-<vendor_slug>`).

---

## Prerequisites

* **Terraform CLI:** `>= 1.5.0`
* **Google Cloud Provider:** `~> 5.40.0`
* **Google Cloud CLI:** Installed and authenticated (`gcloud auth application-default login`)
* **GCP Project & Enabled APIs:**
  * Apigee API (`apigee.googleapis.com`)
  * Compute Engine API (`compute.googleapis.com`)
  * Service Networking API (`servicenetworking.googleapis.com`)
  * Cloud DNS API (`dns.googleapis.com` — required for Pattern III)
* **IAM Privileges:** The deploying identity requires sufficient privileges to create Service Accounts and assign project roles (`roles/iam.serviceAccountCreator`, `roles/resourcemanager.projectIamAdmin`).

---

## Deployment & Usage

### 1. Configure Input Variables

Create a `terraform.tfvars` file:

```hcl
project_id         = "your-gcp-project-id"
vendor_slug        = "acme-corp"
region             = "us-central1"
apigee_hostname    = "api.acme-corp.vendors.example.com"
apigee_org_admins  = ["lead-operator@example.com"]

# Deployment Pattern Selection
dns_managed_by_us    = true
parent_dns_zone_fqdn = "vendors.example.com."
defer_cert           = false
```

### 2. Execution Workflows

#### Pattern III: Automated Cloud DNS (Single Step)
```bash
terraform init
terraform plan
terraform apply
```

#### Pattern I: External DNS (Two-Step Apply)
1. **Step 1: Allocate IP and Infrastructure (Skip Cert)**
   ```bash
   terraform apply -var="defer_cert=true" -var="dns_managed_by_us=false"
   ```
2. **Step 2: Update DNS**
   Retrieve the allocated IP and create an external `A` record pointing your hostname to this IP:
   ```bash
   terraform output -raw lb_ip_address
   # Or via gcloud:
   gcloud compute addresses describe apigee-<vendor_slug>-lb-ip --global --format="value(address)"
   ```
3. **Step 3: Provision Certificate and Forwarding Rule**
   ```bash
   terraform apply -var="defer_cert=false" -var="dns_managed_by_us=false"
   ```

---

## Inputs & Configuration Reference

| Name | Type | Default | Required | Description |
| :--- | :--- | :--- | :---: | :--- |
| `project_id` | `string` | `""` | Yes | Target GCP Project ID. |
| `vendor_slug` | `string` | `"dev-vendor"` | Yes | Primary vendor key (`^[a-z][a-z0-9-]{0,17}$`). |
| `region` | `string` | `"us-central1"` | Yes | GCP region for the Apigee instance (must be allowlisted). |
| `apigee_hostname` | `string` | `""` | Yes | External FQDN served by the Load Balancer / Environment Group. |
| `apigee_org_admins` | `list(string)` | `[""]` | Yes | List of user emails (1–10) granted `roles/apigee.admin`. |
| `runtime_cidr` | `string` | `"10.12.0.0/22"` | No | Peering CIDR range for Apigee runtime (/22 required). |
| `dns_managed_by_us` | `bool` | `false` | No | Enables Pattern III (Cloud DNS managed subzone + A record). |
| `parent_dns_zone_fqdn`| `string` | `""` | No | Parent FQDN with trailing dot (required if `dns_managed_by_us = true`). |
| `defer_cert` | `bool` | `false` | No | Pattern I switch: defers certificate, proxy, and forwarding rule creation. |
| `build_id` | `string` | `""` | No | Cloud Build execution ID for tracking and resource replacement triggers. |

---

## Post-Deployment Validation

**1. Check Apigee Instance and Environment Attachments**
```bash
gcloud apigee instances list --organization="<project_id>"
gcloud apigee environments list --organization="<project_id>"
```

**2. Verify SSL Certificate Provisioning Status**
```bash
gcloud compute ssl-certificates describe "apigee-<vendor_slug>-cert" \
    --global \
    --format="get(managed.status, managed.domainStatus)"
```
*(Note: Google-managed SSL certificates require 15–60 minutes to validate and transition to `ACTIVE` once DNS resolution is live.)*

---

## Teardown

To destroy the provisioned infrastructure:

```bash
terraform destroy
```

> **Warning:** Deleting an Apigee Organization is an irreversible operation and will remove all environments, key-value maps, and proxy configurations deployed within the estate.