output "instance_url" {
  value = "https://${aws_route53_record.rancher.fqdn}"
}

output "rancher_ssh_key" {
  value = "${tls_private_key.rancher_key.private_key_pem}"
}
