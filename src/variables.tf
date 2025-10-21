variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "ID облака"
}

variable "folder_id" {
  type        = string
  description = "ID каталога"
}

variable "default_zone" {
  type    = string
  default = "ru-central1-a"
}

variable "image_id" {
  description = "ID образа LAMP (по условию задания)"
  type        = string
  default     = "fd827b91d99psvq5fjit"
}

variable "instance_group_size" {
  description = "Кол-во VM в группе"
  type        = number
  default     = 3
}

variable "public_key_path" {
  description = "Путь к публичному SSH-ключу (для доступа к VM)"
  type        = string
  default     = "./ed25519.pub"
}

variable "private_key_path" {
  description = "Путь к приватному SSH-ключу (для provisioner, если понадобится)"
  type        = string
  default     = "./ed25519"
}