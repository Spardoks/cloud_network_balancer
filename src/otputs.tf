output "bucket_name" {
  description = "Имя бакета"
  value       = yandex_storage_bucket.bucket.bucket
}

output "picture_url" {
  description = "Публичный URL картинки"
  value       = local.object_url
}

output "all_vms" {
  value = [
    for instance in yandex_compute_instance_group.lamp_group.instances : {
      name = instance.name
      ip_internal = instance.network_interface[0].ip_address
      ip_external = instance.network_interface[0].nat_ip_address}
  ]
}

output "Network_Load_Balancer_Address" {
  value = yandex_lb_network_load_balancer.lamp_lb.listener.*.external_address_spec[0].*.address
  description = "Адрес сетевого балансировщика"
}