variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "instance_ids" {
  description = "Map of server name -> EC2 instance ID to attach a static Elastic IP to"
  type        = map(string)
  default = {
    control-plan = "i-04318a85a8b22639c"
    worker-1     = "i-0fb49c4b52fe4496b"
    worker-2     = "i-0649ef8f0f74e5e3a"
    worker-3     = "i-09dd3ba005a114b7a"
  }
}
