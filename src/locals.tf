# Настройки бакета
locals {
  bucket_name = "spardoks"
  # Имя объекта в бакете
  image_file_name = "picture.jpg"
  # URL публичного объекта (карточка будет доступна без подписи)
  object_url  = "https://storage.yandexcloud.net/${local.bucket_name}/${local.image_file_name}"
  # Путь к файлу-картинке, который будем загружать (можно положить рядом с Terraform-файлами)
  image_file_path = "${path.module}/static/${local.image_file_name}"
}

# Настройки инстансов
locals {
  ssh_user              = "ubuntu"
  ssh_pub_key_content   = file(var.public_key_path)
  ssh_pub_key_formatted = "${local.ssh_user}:${local.ssh_pub_key_content}"
}