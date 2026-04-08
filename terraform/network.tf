resource "google_compute_network" "vpc" {
  name = "${var.app_name}-vpc-network-${var.environment}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
    name = "${var.app_name}-subnetwork-${var.environment}"
    ip_cidr_range = "10.0.0.0/24"
    region        = var.region
    network       = google_compute_network.vpc.id

    private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.app_name}-router-${var.environment}"
  network = google_compute_network.vpc.name
  region = var.region

}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.app_name}-router-nat-${var.environment}"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_vpc_access_connector" "connector" {
  name           = "${var.app_name}-vpc-con-${var.environment}"
  ip_cidr_range  = "10.8.0.0/28"
  network        = google_compute_network.vpc.id
  region         = var.region
  # min_throughput = 200
  # max_throughput = 300
  min_instances = 2
  max_instances = 3
}