/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  type        = string
  default     = ""
  description = "Project ID"
}

variable "vendor_slug" {
  type        = string
  description = "Per-vendor primary key. Lowercase alphanumeric + hyphens; <=18 chars; starts with letter."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,17}$", var.vendor_slug))
    error_message = "vendor_slug must match ^[a-z][a-z0-9-]{0,17}$ (<=18 chars, lowercase, hyphens allowed, starts with letter)."
  }
  default = "dev-vendor"
}


variable "region" {
  type        = string
  description = "Single GCP region for the Apigee instance."
  default     = "us-central1"
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-west1",
      "europe-west1", "asia-southeast1",
    ], var.region)
    error_message = "region must be one of the supported allowlist; add via manifest-repo PR."
  }
}

variable "apigee_hostname" {
  type        = string
  description = "FQDN external clients hit. Must be a subdomain of the parent DNS zone."
  validation {
    condition     = length(var.apigee_hostname) <= 253 && can(regex("^[a-z0-9.-]+$", var.apigee_hostname))
    error_message = "apigee_hostname must be a valid lowercase FQDN, <=253 chars."
  }
  default = ""
}


variable "apigee_org_admins" {
  type        = list(string)
  description = "Principal emails granted roles/apigee.admin on the vendor project. Each entry must match the email regex ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$ (ASCII only, no whitespace, colons, or commas). Corporate-domain enforcement (e.g., '@example.com' only) is the deploy-local wrapper's responsibility; this module is generic and does not know the operator's corporate domain."
  validation {
    condition = (
      length(var.apigee_org_admins) >= 1 &&
      length(var.apigee_org_admins) <= 10 &&
      alltrue([
        for e in var.apigee_org_admins :
        can(regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", e))
      ])
    )
    error_message = "apigee_org_admins must have 1-10 entries; each must match the email regex ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$ (no whitespace, colons, commas, or unicode). Rejects injection patterns like 'user:foo@x.com' and 'a@x.com,b@y.com', and malformed addresses like 'foo@bar' (no TLD). Resolves lumbergh-verify CRITICAL-3 / Bob Security S-1 (OWASP A01 Broken Access Control)."
  }
  default = [""]
}

variable "runtime_cidr" {
  type        = string
  description = "PSA peering range. Must be /22. Allocator is the manifests repo."
  validation {
    condition     = can(regex("^[0-9.]+/22$", var.runtime_cidr))
    error_message = "runtime_cidr must be a /22 CIDR (e.g., 10.10.0.0/22)."
  }
  default = "10.12.0.0/22"
}

variable "dns_managed_by_us" {
  type        = bool
  default     = false
  description = "Pattern selector: false = Pattern I (operator manages DNS externally); true = Pattern III (module creates Cloud DNS managed zone + A record). Default false because D10 (parent-zone delegation authority) is unresolved."
}

variable "parent_dns_zone_fqdn" {
  type        = string
  default     = ""
  description = "Pattern III only: FQDN (with trailing dot) of the parent zone that NS-delegates the vendor's subdomain. E.g., 'vendors.example.com.'. Required when dns_managed_by_us=true; ignored otherwise. The vendor's managed zone is created with dns_name = '<vendor_slug>.<parent_dns_zone_fqdn>'. apigee_hostname MUST be a subdomain of that zone."
  validation {
    condition     = var.parent_dns_zone_fqdn == "" || can(regex("^([a-z0-9-]+\\.)+$", var.parent_dns_zone_fqdn))
    error_message = "parent_dns_zone_fqdn must end with a dot (FQDN form) and contain only lowercase letters, digits, hyphens, and dots."
  }
}

variable "defer_cert" {
  type        = bool
  default     = false
  description = "Pattern-I-only: true = first apply, skip cert + target HTTPS proxy + forwarding rule; operator sets DNS externally; subsequent apply with defer_cert=false provisions the cert. Ignored when dns_managed_by_us=true. Cross-variable constraint (must not combine with dns_managed_by_us=true) is enforced by a check block in main.tf."
}

variable "build_id" {
  type        = string
  default     = ""
  description = "Cloud Build BUILD_ID, passed via -var=build_id=$BUILD_ID. Used to force terraform_data.cert_active replacement on retry builds (resolves OD-012)."
}
