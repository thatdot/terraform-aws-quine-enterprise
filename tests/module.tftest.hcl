# Plan-only tests against a mocked AWS provider: no account or credentials needed.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-west-2"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-12345678"
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-11111111", "subnet-22222222"]
    }
  }
}

variables {
  project_name    = "qe-test"
  container_image = "thatdot/quine-enterprise:2.2.1"
}

run "defaults" {
  command = plan

  variables {
    license_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf:key::"
    java_opts              = "-Dquine.license-server-uri=https://license.thatdot.com"
  }

  assert {
    condition     = aws_lb_target_group.main.health_check[0].path == "/api/v2/system/liveness"
    error_message = "ALB health check should default to the v2 liveness endpoint."
  }

  assert {
    condition     = strcontains(jsondecode(aws_ecs_task_definition.main.container_definitions)[0].healthCheck.command[1], "/api/v2/system/liveness")
    error_message = "Container health check should default to the v2 liveness endpoint."
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.main.container_definitions)[0].secrets == [
      {
        name      = "CONFIG_FORCE_quine_license__key"
        valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf:key::"
      }
    ]
    error_message = "License key must be injected as the CONFIG_FORCE_quine_license__key container secret."
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.main.container_definitions)[0].environment == [
      {
        name  = "ENVIRONMENT"
        value = "dev"
      },
      {
        name  = "JDK_JAVA_OPTIONS"
        value = "-Dquine.license-server-uri=https://license.thatdot.com -Dconfig.override_with_env_vars=true -Dquine.cluster.target-size=1"
      }
    ]
    error_message = "JDK_JAVA_OPTIONS must enable CONFIG_FORCE_* overrides and must not carry the license key."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.ecs_task_execution_secrets.policy).Statement[0].Resource == ["arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf"]
    error_message = "Execution role must be granted the bare secret ARN (without the json-key suffix)."
  }
}

run "user_secrets_are_granted_once_without_ecs_suffix" {
  command = plan

  variables {
    license_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf"
    container_secrets = [
      { name = "DB_USER", valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-AbCdEf:username::" },
      { name = "DB_PASS", valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-AbCdEf:password::" },
      { name = "API_KEY", valueFrom = "arn:aws:ssm:us-west-2:123456789012:parameter/quine/api-key" },
    ]
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.ecs_task_execution_secrets.policy).Statement[0].Resource == [
      "arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf",
      "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-AbCdEf",
      "arn:aws:ssm:us-west-2:123456789012:parameter/quine/api-key",
    ]
    error_message = "Execution role should be granted each secret once, by its bare ARN."
  }
}

run "rejects_reserved_names_and_plain_text_license" {
  command = plan

  variables {
    license_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf"
    java_opts              = "-Dquine.license-key=not-a-real-key"
    container_environment  = [{ name = "JDK_JAVA_OPTIONS", value = "-Xmx6g" }]
    container_secrets      = [{ name = "CONFIG_FORCE_quine_license__key", valueFrom = "arn:aws:ssm:us-west-2:123456789012:parameter/x" }]
  }

  expect_failures = [
    var.java_opts,
    var.container_environment,
    var.container_secrets,
  ]
}

run "rejects_non_arn_inputs" {
  command = plan

  variables {
    license_key_secret_arn = "quine-enterprise/license-key"
    container_secrets      = [{ name = "DB_PASS", valueFrom = "/quine/db-pass" }]
  }

  expect_failures = [
    var.license_key_secret_arn,
    var.container_secrets,
  ]
}

run "license_secret_created_in_same_configuration" {
  command = plan

  module {
    source = "./tests/fixtures/inline_secret"
  }
}
