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
  ssl_certificates = [google_compute_managed_ssl_certificate.this[0].id]
}

resource "google_compute_global_forwarding_rule" "this" {
  count                 = var.defer_cert ? 0 : 1
  provider              = google.vendor
  project               = local.project_id
  name                  = "apigee-${var.vendor_slug}-fwd"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.this[0].id
}
