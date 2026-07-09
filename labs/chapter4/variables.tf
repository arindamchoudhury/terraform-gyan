variable "region" {
  type        = string
  description = "aws region."
  default     = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the lab bucket."
  default     = "hcl-lab-bucket"

}