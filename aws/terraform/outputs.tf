output "elastic_ips" {
  description = "Static public IP per server, stable across stop/start"
  value       = { for name, eip in aws_eip.this : name => eip.public_ip }
}
