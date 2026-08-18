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

