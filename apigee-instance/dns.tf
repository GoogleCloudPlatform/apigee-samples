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
