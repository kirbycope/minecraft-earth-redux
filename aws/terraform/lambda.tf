# The locator / waker. The patched APK's locator points here instead of at the server.
# On every game launch it (1) starts the EC2 instance if it is stopped and (2) answers the locator
# with the server's address. Always on, within the Lambda free tier.

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_wake" {
  statement {
    actions   = ["ec2:StartInstances"]
    resources = [aws_instance.server.arn]
  }
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "waker" {
  name               = "${var.project_name}-waker"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "waker" {
  role   = aws_iam_role.waker.id
  policy = data.aws_iam_policy_document.lambda_wake.json
}

data "archive_file" "waker" {
  type        = "zip"
  source_file = "${path.module}/lambda/waker.py"
  output_path = "${path.module}/.build/waker.zip"
}

resource "aws_lambda_function" "waker" {
  function_name    = "${var.project_name}-waker"
  role             = aws_iam_role.waker.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "waker.handler"
  filename         = data.archive_file.waker.output_path
  source_code_hash = data.archive_file.waker.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      INSTANCE_ID = aws_instance.server.id
      SERVICE_URI = local.service_uri
    }
  }
}

# Public URL. It only ever lives inside your APK. Anyone who learns it can start (not access) your server.
resource "aws_lambda_function_url" "waker" {
  function_name      = aws_lambda_function.waker.function_name
  authorization_type = "NONE"
}

# Since October 2025 a public Function URL needs lambda:InvokeFunction as well as the
# lambda:InvokeFunctionUrl statement the provider adds by itself, or every call is 403.
# The AWS provider (5.x) has no argument for the lambda:InvokedViaFunctionUrl condition, so this
# also allows any AWS principal to invoke the function through the Lambda API. Acceptable here:
# all the function can do is start the instance, which the public URL already allows.
resource "aws_lambda_permission" "waker_url_invoke" {
  statement_id  = "FunctionURLInvokeAllowPublicAccess"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waker.function_name
  principal     = "*"
}
