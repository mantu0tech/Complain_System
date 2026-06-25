# This file is intentionally minimal — provider config lives in main.tf.
# Add data sources here if needed later.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}
