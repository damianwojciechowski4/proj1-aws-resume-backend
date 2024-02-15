provider "aws" {
  region = "eu-central-1"
}

resource "aws_dynamodb_table" "visitors-counter-table" {
  name           = "visitors-counter-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "counterName"
 

  attribute {
    name = "counterName"
    type = "S"
  }
  tags={
    environment = "dev"
  }
}


resource "aws_dynamodb_table_item" "example_item"{
  table_name=aws_dynamodb_table.visitors-counter-table.name
  hash_key = aws_dynamodb_table.visitors-counter-table.hash_key

  item= <<ITEM
  {
    "counterName":{"S" : "visitors"},
    "count":{"N":"0"}  
  }
  ITEM
}

#Dynamically get current AWS region
data "aws_region" "current" {}
#Dynamically get current user ID
data "aws_caller_identity" "current" {}

# Add Lambda Permissions to DynamoDB table
#ARN to dynamodb arn:aws:dynamodb:eu-central-1:891376983633:table/*
# 1. aws_iam_role
resource "aws_iam_role" "lambda_assume_role"{
  name  = "cloudResume-lambda-dynamodb-role"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "LambdaAssumeRole"
    }
  ]
}
EOF

  }
# 2. aws_iam_policy
#create policy for Lambda to read from dynamoDB
resource "aws_iam_policy" "dynamodb_rw_policy"{
  name="cloudResume-lambda-dynamodb-rw-policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:UpdateItem",
                "dynamodb:UpdateTable"
            ],
            "Resource": "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "dynamodb:ListTables",
            "Resource": "*"
        }
    ]
}
EOF
}

# 3. aws_iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role"{
  role = aws_iam_role.lambda_assume_role.name
  policy_arn = aws_iam_policy.dynamodb_rw_policy.arn
}
# 4. data "archive_file"
data "archive_file" "zip_the_python_code"{
  type  = "zip"
  source_dir= "${path.module}/python/"
  output_path = "${path.module}/python/getCounter.zip"
}



# 5. aws_lambda_function
# Create Lambda
resource "aws_lambda_function" "lambda_function" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.

  # Insert python code to Lambda
  filename      = "${path.module}/python/getCounter.zip"   # The filename of the deployment package (ZIP archive) for the Lambda function.
  function_name = "DynamoDB_LambdaFunction"         # The name of the Lambda function.
  role          = aws_iam_role.lambda_assume_role.arn # The Amazon Resource Name (ARN) of the IAM role that the Lambda function will assume.
  handler       = "getCounter.lambda_handler"                    # The name of the function (within your code) that Lambda calls to start execution.
  runtime       = "python3.10"


# Configure Environment Variables for Lambda
  environment {
    variables = {
      TABLE_NAME = "visitors-counter-table"
    }
  }
}

resource "aws_apigatewayv2_api" "exampleAPI" {
    name = "exampleAPI_lambda"
    protocol_type = "HTTP"
    cors_configuration {
      allow_headers     = ["Content-Type"]
      allow_methods     = ["*"]
      allow_origins     = ["*"]
      expose_headers = ["*"]
      max_age           = 300
  }

}

resource "aws_apigatewayv2_stage" "exampleStage" {
    api_id = aws_apigatewayv2_api.exampleAPI.id
    name = "exampleStage"
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "exampleIntergration" {
    api_id = aws_apigatewayv2_api.exampleAPI.id

    integration_uri = aws_lambda_function.lambda_function.invoke_arn
    integration_type = "AWS_PROXY"
    integration_method = "POST"
}


resource "aws_apigatewayv2_route" "exampleRoute" {
    api_id = aws_apigatewayv2_api.exampleAPI.id
    route_key = "GET /VistorsCounter"
    target = "integrations/${aws_apigatewayv2_integration.exampleIntergration.id}"
}


resource "aws_lambda_permission" "examplePermission" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda_function.function_name
    principal = "apigateway.amazonaws.com"

    source_arn = "${aws_apigatewayv2_api.exampleAPI.execution_arn}/*/*"
    
  
}

output "base_url" {
    value = "${aws_apigatewayv2_stage.exampleStage.invoke_url}/VistorsCounter"
}