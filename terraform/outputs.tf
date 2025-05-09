output "load_balancer_url" {
  value = aws_lb.app.dns_name
}
