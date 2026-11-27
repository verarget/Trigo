output "load_balancer_ip" {
  value = google_compute_global_address.web.address
}

output "application_url" {
  value = "http://${google_compute_global_address.web.address}"
}

output "instance_group_name" {
  value = google_compute_instance_group_manager.web.name
}