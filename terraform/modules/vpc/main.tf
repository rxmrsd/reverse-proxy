resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id

  # Ensure network is deleted after all dependent resources
  lifecycle {
    create_before_destroy = false
    prevent_destroy       = false
  }
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.network_name}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  project                  = var.project_id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"

  # Ensure subnet is deleted after all services using it are removed
  lifecycle {
    create_before_destroy = false
    prevent_destroy       = false
  }

  depends_on = [google_compute_network.vpc_network]
}
