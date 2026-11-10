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
    condition = one([
      for env in jsondecode(aws_ecs_task_definition.main.container_definitions)[0].environment :
      env.value if env.name == "JDK_JAVA_OPTIONS"
    ]) == "-Dconfig.override_with_env_vars=true -Dquine.cluster.target-size=1"
    error_message = "JDK_JAVA_OPTIONS must enable CONFIG_FORCE_* overrides, and not carry the license key."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.ecs_task_execution_secrets.policy).Statement[0].Resource == ["arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf"]
    error_message = "Execution role must be granted the bare secret ARN (without the json-key suffix)."
  }
}

run "user_secrets_are_granted_once_without_ecs_suffix" {
  command = plan

  variables {
    license_key_secret_arn = "arn:aws:ssm:us-west-2:123456789012:parameter/quine-enterprise/license-key"
    java_opts              = "-Xmx3g"
    container_secrets = [
      { name = "DB_USER", valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-AbCdEf:username::" },
      { name = "DB_PASS", valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-AbCdEf:password::" },
      { name = "API_KEY", valueFrom = "arn:aws:ssm:us-west-2:123456789012:parameter/quine/api-key" },
    ]
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.ecs_task_execution_secrets.policy).Statement[0].Resource == [
      "arn:aws:ssm:us-west-2:123456789012:parameter/quine-enterprise/license-key",
      "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-AbCdEf",
      "arn:aws:ssm:us-west-2:123456789012:parameter/quine/api-key",
    ]
    error_message = "Execution role should be granted each secret once, by its bare ARN."
  }

  assert {
    condition = startswith(one([
      for env in jsondecode(aws_ecs_task_definition.main.container_definitions)[0].environment :
      env.value if env.name == "JDK_JAVA_OPTIONS"
    ]), "-Xmx3g -Dconfig.override_with_env_vars=true")
    error_message = "User java_opts must come first in JDK_JAVA_OPTIONS, followed by the module's options."
  }
}

run "rejects_duplicate_container_variable_names" {
  command = plan

  variables {
    license_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:quine-enterprise/license-key-AbCdEf"
    container_environment = [
      { name = "JDK_JAVA_OPTIONS", value = "-Xmx6g" },
      { name = "CONFIG_FORCE_quine_license__key", value = "not-a-real-key" },
    ]
    container_secrets = [
      { name = "JDK_JAVA_OPTIONS", valueFrom = "arn:aws:ssm:us-west-2:123456789012:parameter/x" },
      { name = "CONFIG_FORCE_quine_license__key", valueFrom = "arn:aws:ssm:us-west-2:123456789012:parameter/y" },
    ]
  }

  expect_failures = [
    aws_ecs_task_definition.main,
  ]
}

run "rejects_malformed_inputs" {
  command = plan

  variables {
    license_key_secret_arn = "quine-enterprise/license-key"
    container_secrets      = [{ name = "DB_PASS", valueFrom = "arn:aws:ssm:us-west-2:123456789012:parameter/db-pass\n" }]
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
