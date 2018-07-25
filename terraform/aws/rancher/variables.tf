variable instance_type {
  description = "The machine type for rancher server"
  type        = "string"
  default     = "m4.xlarge"
}

variable volume_size {
  description = "The machine volume size in GB"
  default     = "50"
}

variable region {
  description = "AWS region"
  type        = "string"
  default     = "us-east-2"
}

variable "rancher_clc_snippets" {
  type        = "list"
  description = "Rancher Container Linux Config snippets"
  default     = []
}

variable "public_domain" {
  description = "Public domain to setup dns record for rancher url"
  type        = "string"
}

variable "unique_name" {
  description = "Name to tag instance"
  type        = "string"
  default     = "rancher"
}

variable "etcd_ebs_snapshot_id" {
  description = "If this value is set it'll be used as base to create the EBS for rancher"
  type        = "string"
  default     = ""
}

variable "coreos_channel" {
  default = "stable"
}

variable "assume_role_arn" {
  description = "AWS role account to assume"
  type        = "string"
}
