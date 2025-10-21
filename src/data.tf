# Читаем локальный файл-картинку (должен находиться в ./static/picture.jpg)
data "local_file" "picture" {
  filename = local.image_file_path
}