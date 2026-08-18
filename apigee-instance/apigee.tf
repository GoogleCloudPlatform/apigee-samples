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
