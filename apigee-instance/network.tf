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
  project                 = local.project_id #google_project.this.project_id
  name                    = "apigee-${var.vendor_slug}"
  auto_create_subnetworks = false
  #depends_on              = [null_resource.iam_readiness]
}

# Create the Subnetwork
resource "google_compute_subnetwork" "this" {
  name          = "apigee-${var.vendor_slug}-sub"
  project       = local.project_id
  ip_cidr_range = "10.0.1.0/24"      
  region        = var.region          
  network       = google_compute_network.this.id
  private_ip_google_access = true    
}

resource "google_compute_global_address" "psa_range" {
  provider      = google.vendor
  project       = local.project_id #google_project.this.project_id
  name          = "apigee-psa-final"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.this.id
  address       = "10.46.208.0"
}

resource "google_service_networking_connection" "psa" {
  provider                = google.vendor
  network                 =  google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}
