variable PRE {
  type = string
  default = "prefix-"
  description = "prefix for all resources names"
}
variable OWNER {
  type = string
  default = "owner"
  description = "owner of all resources (nick)"
}
variable AWS_REGION {
  type = string
  default = "us-east-1"
}
variable AWS_PA_USER {
  type = string
  description = "programmatic access user's arn"
}