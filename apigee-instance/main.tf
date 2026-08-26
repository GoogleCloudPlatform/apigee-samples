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


# [START alm_apigee_instance]
### apigee instance ###

locals {

 project_id = var.project_id

}
resource "google_apigee_organization" "this" {
  provider           = google.vendor
  project_id         = local.project_id 
  analytics_region   = "us-west1"
  authorized_network = google_compute_network.this.id 
  runtime_type       = "CLOUD"
  # HLD Q1: verify "PAYG" against pinned provider 5.40.0 at
  # impl time. If the provider rejects the string, the alternate
  # accepted value is "PAYASYOUGO" - this has changed historically.
  billing_type = "PAYG"
  depends_on   = [google_service_networking_connection.psa]
}

resource "google_apigee_environment" "prod" {
  provider     = google.vendor
  org_id       = google_apigee_organization.this.id
  name         = "prod"
  display_name = "Production environment for vendor ${var.vendor_slug}"
}

resource "google_apigee_instance" "this" {
  provider = google.vendor
  org_id   = google_apigee_organization.this.id
  name     = "instance-${var.region}"
  location = var.region
}

resource "google_apigee_instance_attachment" "prod" {
  provider    = google.vendor
  instance_id = google_apigee_instance.this.id
  environment = google_apigee_environment.prod.name
}

resource "google_apigee_envgroup" "this" {
  provider  = google.vendor
  org_id    = google_apigee_organization.this.id
  name      = "envgroup-${var.vendor_slug}"
  hostnames = [var.apigee_hostname]
}

resource "google_apigee_envgroup_attachment" "this" {
  provider    = google.vendor
  envgroup_id = google_apigee_envgroup.this.id
  environment = google_apigee_environment.prod.name
}

### dns ###

# Pattern III only (var.dns_managed_by_us = true). In Pattern I,
# this file produces zero resources - the operator manages DNS
# externally.
#
# The vendor's managed zone is a subdomain of the parent zone the
# team owns. The dns_name is "{vendor_slug}.{parent_dns_zone_fqdn}"
# so each vendor gets a discrete delegated subzone (e.g.,
# 'mongodb.vendors.example.com.'). apigee_hostname must be a name
# under this subzone (e.g., 'api.mongodb.vendors.example.com').

locals {
  # Only meaningful when var.dns_managed_by_us = true.
  vendor_subzone_dns_name = "${var.vendor_slug}.${var.parent_dns_zone_fqdn}"
}

resource "google_dns_managed_zone" "vendor" {
  count       = var.dns_managed_by_us ? 1 : 0
  provider    = google.vendor
  project     = local.project_id
  name        = "apigee-${var.vendor_slug}-zone"
  dns_name    = local.vendor_subzone_dns_name
  description = "Vendor-${var.vendor_slug} subzone; NS-delegated from ${var.parent_dns_zone_fqdn}."

  lifecycle {
    precondition {
      condition     = var.parent_dns_zone_fqdn != ""
      error_message = "parent_dns_zone_fqdn must be set when dns_managed_by_us=true."
    }
    precondition {
      condition     = endswith("${var.apigee_hostname}.", local.vendor_subzone_dns_name)
      error_message = "apigee_hostname (${var.apigee_hostname}) must be a subdomain of ${local.vendor_subzone_dns_name}. Either change apigee_hostname or change parent_dns_zone_fqdn so the subzone matches."
    }
  }
}

resource "google_dns_record_set" "apigee_a" {
  count        = var.dns_managed_by_us ? 1 : 0
  provider     = google.vendor
  project      = local.project_id
  managed_zone = google_dns_managed_zone.vendor[0].name
  name         = "${var.apigee_hostname}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

### iam ###

# Per-vendor provisioner SA (created by minter; subsequently used
# as the identity for the google.vendor provider alias).
#
# OD-009 disposition: the roles/owner grant on the per-vendor SA
# IS the per-vendor blast-radius boundary. The minter SA holds no
# project-level grants on any vendor project; the per-vendor SA's
# blast radius is exactly the vendor project. This deviates from
# SCOPE.md §7's "no project-level Owner/Editor" language; the
# disposition is documented in DESIGN_DOC.md §13 and accepted
# pending Phase 5 CSO audit. Narrower role-set is not available
# from the GCP role catalog without composing custom roles, which
# would multiply maintenance surface.
resource "google_service_account" "per_vendor" {
  project      = local.project_id
  account_id   = "provisioner-${var.vendor_slug}"
  display_name = "Provisioner SA for vendor ${var.vendor_slug}"
}

resource "google_project_iam_member" "per_vendor_owner" {
  project = local.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.per_vendor.email}"
}

# Apigee org-admin grants for the input apigee_org_admins list.
# These run via google.vendor (the per-vendor SA), so the trust
# boundary is: minter creates vendor SA + grants Owner; vendor SA
# subsequently grants Apigee admin to the named operators. Org
# admins never receive project-level Owner/Editor.
resource "google_project_iam_member" "org_admins" {
  for_each = toset(var.apigee_org_admins)

  provider   = google.vendor
  project    = local.project_id
  role       = "roles/apigee.admin"
  member     = "user:${each.value}"
  depends_on = [google_apigee_organization.this]
}

# Downstream-consumer SA (used by Pranav's flow to deploy proxies
# into the env). LLD commit: roles/apigee.environment.admin
# pending Pranav coordination (HLD Q9 / OD-003). If Pranav's coord
# meeting produces a narrower custom-role requirement, swap to
# that here; the SA itself is stable.
resource "google_service_account" "downstream_consumer" {
  provider     = google.vendor
  project      = local.project_id
  account_id   = "proxy-deployer-${var.vendor_slug}"
  display_name = "Downstream proxy-deployment SA for vendor ${var.vendor_slug}"
  #depends_on   = [null_resource.iam_readiness]
}


### load balancer ###

# Always created (Pattern I and Pattern III, deferred and
# non-deferred): the LB IP, PSC NEG, backend service, and URL
# map. These give the vendor estate a stable global address
# that the operator can point DNS at in Pattern I deferred mode.
resource "google_compute_global_address" "lb_ip" {
  provider     = google.vendor
  project      = local.project_id
  name         = "apigee-${var.vendor_slug}-lb-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# PSC NEG pointing at the Apigee instance's service attachment.
#
# DIVERGENCE FROM IMPL_DETAILS.md §10.1: IMPL_DETAILS.md used
# `google_compute_network_endpoint_group` for the PSC NEG, but
# `psc_target_service` and the `region` attribute are only valid
# on the regional variant `google_compute_region_network_endpoint_group`
# in google provider 5.40.0. The global/zonal
# `google_compute_network_endpoint_group` does not accept these
# fields. Using the regional variant here keeps the design intent
# (regional PSC NEG -> Apigee instance service attachment) and
# matches the actual provider schema. This is a documentation
# correction, not a design change; surfaced for the verify
# phase to consider patching IMPL_DETAILS.md.
resource "google_compute_region_network_endpoint_group" "psc_neg" {
  provider              = google.vendor
  project               = local.project_id
  name                  = "apigee-${var.vendor_slug}-psc-neg"
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_apigee_instance.this.service_attachment
  region                = var.region
  network               = google_compute_network.this.id
  subnetwork            = google_compute_subnetwork.this.id
}

resource "google_compute_backend_service" "apigee" {
  provider              = google.vendor
  project               = local.project_id
  name                  = "apigee-${var.vendor_slug}-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  backend {
    group = google_compute_region_network_endpoint_group.psc_neg.id
  }
}

resource "google_compute_url_map" "this" {
  provider        = google.vendor
  project         = local.project_id
  name            = "apigee-${var.vendor_slug}-url-map"
  default_service = google_compute_backend_service.apigee.id
}

# Conditional on defer_cert=false: cert + HTTPS proxy + forwarding rule.
# Pattern III: always created (defer_cert is validated to be false
#   when dns_managed_by_us=true via the variables.tf validation
#   block).
# Pattern I single-apply: created (operator pre-set DNS).
# Pattern I deferred:     NOT created on first apply; created on second.
resource "google_compute_managed_ssl_certificate" "this" {
  count    = var.defer_cert ? 0 : 1
  provider = google.vendor
  project  = local.project_id
  name     = "apigee-${var.vendor_slug}-cert"
  managed {
    domains = [var.apigee_hostname]
  }
  # Pattern III: explicit dependency on the A record this module
  # creates (via the count-conditional resource list - empty in
  # Pattern I, single-element in Pattern III). Pattern I: the
  # depends_on list is empty; correctness for Pattern I relies
  # on the operator having configured DNS externally before this
  # apply runs, with cert-poll surfacing FAILED_NOT_VISIBLE
  # otherwise.
  depends_on = [google_dns_record_set.apigee_a]
}

resource "google_compute_target_https_proxy" "this" {
  count            = var.defer_cert ? 0 : 1
  provider         = google.vendor
  project          = local.project_id
  name             = "apigee-${var.vendor_slug}-https-proxy"
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this[count.index].id]
}

resource "google_compute_global_forwarding_rule" "this" {
  count                 = var.defer_cert ? 0 : 1
  provider              = google.vendor
  project               = local.project_id
  name                  = "apigee-${var.vendor_slug}-fwd"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.this[count.index].id
}
### network ###

# Apigee X's runtime is fully managed by Google and does not
# consume subnet IPs in the customer's VPC. The PSA reservation
# (/22) is the only address space the customer must commit; no
# subnet is required for the Apigee module itself.
#
# The PSC NEG (in lb.tf) uses a regional NEG that targets the
# Apigee service attachment - it does not require its own subnet
# in this VPC. (PSC NEGs of type PRIVATE_SERVICE_CONNECT do not
# have backend instances; they forward to the service attachment
# URI directly.) Resolves Goldfish R1 C-6.
#
# If a future need arises (e.g., custom VMs that talk to Apigee
# privately), add a subnet at a CIDR DISJOINT from
# var.runtime_cidr. The manifests-repo CIDR allocator MUST be
# extended at that time to track both the PSA /22 and the new
# subnet CIDR.
resource "google_compute_network" "this" {
  provider                = google.vendor
  project                 = local.project_id 
  name                    = "apigee-${var.vendor_slug}"
  auto_create_subnetworks = false
  
}

# Create the Subnetwork
resource "google_compute_subnetwork" "this" {
  provider      = google.vendor
  name          = "apigee-${var.vendor_slug}-sub"
  project       = local.project_id
  ip_cidr_range = "10.0.1.0/24"      
  region        = var.region          
  network       = google_compute_network.this.id
  private_ip_google_access = true    
}

resource "google_compute_global_address" "psa_range" {
  provider      = google.vendor
  project       = local.project_id 
  name          = "apigee-psa-final"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = split("/", var.runtime_cidr)[1]
  network       = google_compute_network.this.id
  address       = split("/", var.runtime_cidr)[0]
}

resource "google_service_networking_connection" "psa" {
  provider                = google.vendor
  network                 =  google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}

# [END alm_apigee_instance]