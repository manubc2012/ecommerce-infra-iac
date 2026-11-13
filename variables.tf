variable "aws_region" {
  description = "Región de AWS (us-east-1 recomendada para AWS Academy)"
  type        = string
  default     = "us-east-1"
}

variable "env_name" {
  description = "Nombre del ambiente (dev, qa, prod)"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (Capa gratuita / AWS Academy)"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_instances" {
  description = "Cantidad mínima de instancias en el clúster"
  type        = number
  default     = 2
}

variable "asg_desired_instances" {
  description = "Cantidad deseada de instancias activas"
  type        = number
  default     = 2

  validation {
    condition     = var.asg_desired_instances >= 1 && var.asg_desired_instances <= 8
    error_message = "Política FinOps: el clúster no puede superar el techo de 8 instancias."
  }
}

variable "asg_max_instances" {
  description = "Techo máximo de escalado automático"
  type        = number
  default     = 6
}

variable "ami_id" {
  description = "AMI fija de Amazon Linux 2023. Cambia solo mediante RFC."
  type        = string
}