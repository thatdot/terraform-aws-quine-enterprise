# Test fixture: the license secret is created in the same configuration as the
# module, so its ARN is unknown at plan time and the module must still plan.

variable "container_image" {
  type = string
}

resource "aws_secretsmanager_secret" "license" {
  name = "quine-enterprise-test/license-key"
}

module "quine_enterprise" {
  source = "../../../"

  project_name           = "qe-inline-secret"
  container_image        = var.container_image
  license_key_secret_arn = aws_secretsmanager_secret.license.arn
}
