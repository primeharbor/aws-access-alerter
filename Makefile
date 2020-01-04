

ifndef BUCKET
$(error BUCKET is not set)
endif

# Specific to this stack
export STACK_NAME=aws-iam-access-alerter
# Filename for the CFT to deploy
export SAM_TEMPLATE=IAM-Access-Alerter-SAM-Template.yaml
export STACK_TEMPLATE=IAM-Access-Alerter-QuickLink-Template.yaml
# Name of the Zip file with all the function code and dependencies
export LAMBDA_PACKAGE=lambda-package.zip

# Application Variables
export AUTHOR=Chris Farris
export DESCRIPTION=Generate Email Alerts from the IAM Access Analyzer
export GITHUB=https://github.com/jchrisfarris/aws-access-alerter
export HOMEPAGE=https://www.chrisfarris.com/
export LICENSE=MIT

FUNCTIONS=$(STACK_NAME)-send-email

.PHONY: $(FUNCTIONS)

# Run all tests
test: cfn-validate
	cd lambda && $(MAKE) test

clean:
	cd lambda && $(MAKE) clean

#
# Lambda Targets
#

# Build a clean lambda package for publishing
package:
	cd lambda && $(MAKE) package

# just re-zip up the code
zipfile:
	cd lambda && $(MAKE) zipfile

# Pushes to S3 Bucket for use with the non-SAM CFT
upload: package
ifndef version
	$(error version not set)
else
	aws s3 cp lambda/$(LAMBDA_PACKAGE) s3://$(BUCKET)/$(STACK_NAME)-$(version)-lambda.zip
	aws s3 cp $(STACK_TEMPLATE) s3://$(BUCKET)/$(STACK_NAME)-$(version)-Template.yaml
endif

#
## SAM/SAR Targets
#
# Create the SAM Template file
template: package
	aws cloudformation package --template $(SAM_TEMPLATE) --s3-bucket $(BUCKET) --output-template-file $(STACK_NAME).output.yaml

# Create the SAR Application. This is only needed once
create-sar-application:
	aws serverlessrepo create-application \
	--author "$(AUTHOR)" \
	--description "$(DESCRIPTION)" \
	--name $(STACK_NAME) \
	--spdx-license-id $(LICENSE) \
	--readme-body file://SAM-README.md \
	--home-page-url $(HOMEPAGE) \
	--license-body file://LICENSE

update-sar-application:
	$(eval APPID := $(shell aws serverlessrepo list-applications --query 'Applications[?Name==`$(STACK_NAME)`].ApplicationId' --output text))
	aws serverlessrepo update-application \
	--application-id $(APPID) \
	--author "$(AUTHOR)" \
	--description "$(DESCRIPTION)" \
	--readme-body file://SAM-README.md \
	--home-page-url $(HOMEPAGE)

# Release a new version of the software
sar-release: package template
ifndef version
	$(error version not set)
else
	$(eval app_arn := $(shell aws serverlessrepo list-applications | jq -r '.Applications[]  | select(.Name == "$(STACK_NAME)") | .ApplicationId'))
	aws serverlessrepo create-application-version \
	--application-id $(app_arn) \
	--semantic-version $(version) \
	--source-code-url $(GITHUB) \
	--template-body file://$(STACK_NAME).output.yaml
endif

#
# Local Deploy & Testing Targets
#

# For deploying locally for testing
deploy: package template
ifndef email
	$(error email not set)
else
	aws cloudformation deploy --template-file $(STACK_NAME).output.yaml --stack-name $(STACK_NAME) --capabilities CAPABILITY_IAM --parameter-overrides pCreateAnalyzer=False pEmailAddress=$(email) pDebug=True
endif


# Validate the template
cfn-validate: $(SAM_TEMPLATE)
	cft-validate --region $(AWS_DEFAULT_REGION) --template $(SAM_TEMPLATE)
	cft-validate --region $(AWS_DEFAULT_REGION) --template $(STACK_TEMPLATE)


# # # Update the Lambda Code without modifying the CF Stack
update: zipfile
	for f in $(FUNCTIONS) ; do \
	  aws lambda update-function-code --function-name $$f --zip-file fileb://lambda/$(LAMBDA_PACKAGE) ; \
	done
