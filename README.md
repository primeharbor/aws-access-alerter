# aws-access-alerter
Generates Email Alerts when a new Public Resource is discovered by AWS Analyzer

CloudFormation deploy AWS's new IAM Access Analyzer and a lambda that will use SES to notify you of the findings.

*Get Emails when someone in your account makes something public!*


## What this does

Deploys AWS IAM Access Analyzer in your region, then configures an EventBridge rule to send findings to an SNS Topic. A Lambda on the Topic will forward all findings to the email address you specify.

You can add additional automations to the SNS topic to send these to Slack or other notification systems, or to create a lambda to remove the resource.

**NOTE:** This doesn't yet support the auto-archive or other trust filtering mechanisms.

## Email Subject types:

* *"New Public Resource found in {account_desc}"* - When the resource is fully public
* *"New SAML Federation found in {account_desc}"* - Notifies about SAML Trust issues
* *"New cross-account role found in {account_desc}"* - Notifies about Cross Account Roles
* *"New un-authenticated resource found in {account_desc}"* - Notifies about public resources protected by conditions
* *"New Resource trust found in {account_desc}"* - All other findings

**WARNING! IAM Access Analyzer is a region-specific service and must be deployed in all regions to provide full coverage**

## Deploy
* [QuickLink](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateUrl=https%3A%2F%2Fpht-cloudformation.s3.amazonaws.com%2Faws-iam-access-alerter%2FTemplate-0.0.5.yaml&stackName=iam-alerter&param_pCreateAnalyzer=True&param_pDebug=False&param_pEmailAddress=NONE&param_pEmailSender=NONE&param_pLambdaBucket=pht-cloudformation&param_pLambdaObject=aws-iam-access-alerter%2Flambda-0.0.5.zip)
* [ServerlessAppRepo](https://console.aws.amazon.com/lambda/home#/create/app?applicationId=arn:aws:serverlessrepo:us-east-1:658643464782:applications/aws-iam-access-alerter)