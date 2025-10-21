#############################
# Object Storage
#############################
resource "yandex_storage_bucket" "bucket" {
  bucket = local.bucket_name
  # Делать весь бакет публичным можно через policy, но проще задать публичность на уровне объекта
}

resource "yandex_storage_object" "picture" {
  bucket = yandex_storage_bucket.bucket.id
  key    = local.image_file_name

  content = data.local_file.picture.content
  # Делаем объект публичным
  acl     = "public-read"
}



#############################
# Сеть + firewall
#############################
resource "yandex_vpc_network" "net" {
  name = "lamp-net"
}

resource "yandex_vpc_subnet" "public_subnet" {
  name           = "public-subnet"
  network_id     = yandex_vpc_network.net.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.0.0.0/24"]
}

resource "yandex_vpc_security_group" "allow_http_ssh" {
  name        = "allow-http-ssh"
  network_id  = yandex_vpc_network.net.id
  description = "Разрешаем SSH и HTTP"

  ingress {
    description = "SSH"
    protocol    = "tcp"
    port        = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    protocol    = "tcp"
    port        = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Все исходящие"
    protocol    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}



#############################
# Service Account (для работы Instance Group)
#############################
resource "yandex_iam_service_account" "lamp_sa" {
  name = "lamp-sa"
  description = "Сервисный аккаунт для управления группой ВМ."
}

resource "yandex_resourcemanager_folder_iam_member" "lamp_sa_group_editor" {
  folder_id  = var.folder_id
  role       = "editor"
  #role      = "storage.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.lamp_sa.id}"
  depends_on = [
    yandex_iam_service_account.lamp_sa,
  ]
}



#############################
# Instance Group (3 VM)
#############################
resource "yandex_compute_instance_group" "lamp_group" {
  name               = "lamp-group"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.lamp_sa.id
  instance_template {
    platform_id = "standard-v1"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = var.image_id
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public_subnet.id]
      nat       = true   # Чтобы каждая VM имела внешний IP (для отладки)
      security_group_ids = [yandex_vpc_security_group.allow_http_ssh.id]
    }

    metadata = {
    ssh-keys = local.ssh_pub_key_formatted
    serial-port-enable = "1"
    #user-data  = file("${path.module}/cloudinit.yaml")
    user-data   = <<EOF
#!/bin/bash
cd /var/www/html
echo '<html><head><title>My picture</title></head> <body><h1>Look at my picture on host ' > index.html
echo $(hostname) >> index.html
echo '</h1><img src="${local.object_url}"/></body></html>' >> index.html
EOF
    }
  }

  scale_policy {
    fixed_scale {
      size = var.instance_group_size
    }
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  # Добавляем метку, чтобы потом легко отфильтровать в LB
  labels = {
    env = "demo"
  }

  # Указываем, что в группе нужен health-check (чтобы LB мог проверить)
  health_check {
    #name = "http-check"
    http_options {
      port = 80
      path = "/"
    }
    interval = 5
    timeout  = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.lamp_sa_group_editor,
  ]
}



#############################
# Target Group для LB
#############################
resource "yandex_lb_target_group" "lamp_tg" {
  name = "lamp-tg"
  
  dynamic "target" {
    for_each = range(var.instance_group_size)
    content {
      subnet_id = yandex_vpc_subnet.public_subnet.id
      address   = yandex_compute_instance_group.lamp_group.instances[target.key].network_interface[0].ip_address
    }
  }
  
  depends_on = [
    yandex_compute_instance_group.lamp_group,
  ]
}



#############################
# Сетевой Load Balancer
#############################
resource "yandex_lb_network_load_balancer" "lamp_lb" {
  name = "lamp-nlb"

  listener {
    name        = "http-listener"
    port        = 80
    target_port = 80
    protocol    = "tcp"
	external_address_spec {
      ip_version = "ipv4"
    }
  }
  
  attached_target_group {
    target_group_id = yandex_lb_target_group.lamp_tg.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
  
  depends_on = [
    yandex_lb_target_group.lamp_tg,
  ]
}