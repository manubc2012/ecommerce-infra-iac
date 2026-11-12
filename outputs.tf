output "vpc_id" {
  description = "ID de la VPC creada en AWS"
  value       = aws_vpc.ecommerce_vpc.id
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group desplegado"
  value       = aws_autoscaling_group.ecommerce_asg.name
}

output "capacidad_deseada_actual" {
  description = "Número de instancias configuradas como estado deseado"
  value       = aws_autoscaling_group.ecommerce_asg.desired_capacity
}