output "public_ip" {
  description = "The server's Elastic IP. Bake this into the APK as the API/login address."
  value       = aws_eip.server.public_ip
}

output "api_url" {
  value = local.service_uri
}

output "locator_url" {
  description = "Point the APK's locator here. Every game launch hits it, which wakes a stopped server."
  value       = aws_lambda_function_url.waker.function_url
}

output "patch_apk_command" {
  description = "Run from the repo root with the original 0.33.0 APK to build the client for this server."
  value       = "patcher/patch-apk.sh Minecraft_Earth_0.33.0.apk out/earth.apk ${aws_eip.server.public_ip}:${var.api_port} ${aws_lambda_function_url.waker.function_url}"
}

output "ssh" {
  value = "ssh ubuntu@${aws_eip.server.public_ip}"
}

output "launcher_admin_tunnel" {
  description = "The admin UI is not exposed. Tunnel it, then open http://localhost:5055 (5055 locally because macOS AirPlay holds 5000) and register the first (owner) account."
  value       = "ssh -L 5055:localhost:5000 ubuntu@${aws_eip.server.public_ip}"
}

output "aws_region" {
  value = var.aws_region
}
