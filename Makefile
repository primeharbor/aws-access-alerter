# MIT License

# Copyright (c) 2019-2023 Chris Farris <chris@primeharbor.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

ifndef BUCKET
$(error BUCKET is not set)
endif

# Specific to this stack
export STACK_NAME=aws-iam-access-alerter
# Filename for the CFT to deploy
export SAM_TEMPLATE=IAM-Access-Alerter-SAM-Template.yaml
# Name of the Zip file with all the function code and dependencies
export LAMBDA_PACKAGE=lambda-package.zip

# Application Variables
export AUTHOR=Chris Farris
export DESCRIPTION=Generate Email Alerts from the IAM Access Analyzer
export GITHUB=https://github.com/primeharbor/aws-access-alerter
export HOMEPAGE=https://www.primeharbor.com/projects/aws-access-alerter
export LICENSE=MIT

FUNCTIONS=$(STACK_NAME)-send-email

.PHONY: $(FUNCTIONS)

# Run all tests
test: cfn-validate
	cd lambda && $(MAKE) test

clean:
	cd lambda && $(MAKE) clean

#
## SAM/SAR Targets
#
# Create the SAM Template file
template:
	aws cloudformation package --template $(SAM_TEMPLATE) --s3-bucket $(BUCKET) --output-template-file $(STACK_NAME).output.yaml

# Create the SAR Application. This is only needed once
create-sar-application:
	aws serverlessrepo create-application --output text \
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
	--home-page-url $(HOMEPAGE) --output text

# Release a new version of the software
sar-release: template
ifndef version
	$(error version not set)
else
	$(eval app_arn := $(shell aws serverlessrepo list-applications | jq -r '.Applications[]  | select(.Name == "$(STACK_NAME)") | .ApplicationId'))
	aws serverlessrepo create-application-version --output text \
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


# # # Update the Lambda Code without modifying the CF Stack
update: zipfile
	for f in $(FUNCTIONS) ; do \
	  aws lambda update-function-code --function-name $$f --zip-file fileb://lambda/$(LAMBDA_PACKAGE) ; \
	done
