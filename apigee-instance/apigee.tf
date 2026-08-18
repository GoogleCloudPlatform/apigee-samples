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
