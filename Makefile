export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

usage:			## Show this help in table format
	@echo "| Target                 | Description                                                       |"
	@echo "|------------------------|-------------------------------------------------------------------|"
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/:.*##\s*/##/g' | awk -F'##' '{ printf "| %-22s | %-65s |\n", $$1, $$2 }'

check:			## Check if all required prerequisites are installed
	@command -v docker > /dev/null 2>&1 || { echo "Docker is not installed. Please install Docker and try again."; exit 1; }
	@command -v aws > /dev/null 2>&1 || { echo "AWS CLI is not installed. Please install AWS CLI and try again."; exit 1; }
	@command -v lstk > /dev/null 2>&1 || { echo "lstk is not installed. Please install lstk and try again."; exit 1; }
	@command -v python3 > /dev/null 2>&1 || { echo "Python 3 is not installed. Please install Python 3 and try again."; exit 1; }
	@echo "All required prerequisites are available."

deploy:		## Setup the architecture
	@echo "Deploying the architecture..."
	@echo "Create S3 bucket and upload the CloudFormation template..."
	lstk aws s3 mb s3://covid19-lake; \
	lstk aws s3 cp cloudformation-templates/CovidLakeStack.template.json s3://covid19-lake/cfn/CovidLakeStack.template.json; \
	lstk aws s3 sync ./covid19-lake-data/ s3://covid19-lake/; \
	lstk aws cloudformation create-stack --stack-name covid-lake-stack --template-url http://s3.localhost.localstack.cloud:4566/covid19-lake/cfn/CovidLakeStack.template.json
	@counter=0; \
	while [ $$counter -lt 30 ]; do \
		status=$$(lstk aws cloudformation describe-stacks --stack-name covid-lake-stack | grep StackStatus | cut -d'"' -f4); \
		echo "Attempt $$counter: Stack status: $$status"; \
		if [ "$$status" = "CREATE_COMPLETE" ]; then \
			echo "Stack creation completed successfully!"; \
			exit 0; \
		fi; \
		counter=$$((counter+1)); \
		if [ $$counter -lt 30 ]; then sleep 2; fi; \
	done; \
	echo "Stack creation timed out after 30 attempts"; \
	exit 1

test:		## Run the tests
	@echo "Installing dependencies..."
	@pip3 install -r tests/requirements.txt
	@echo "Running tests..."
	python3 -m pytest -s -v --disable-warnings tests/
	@echo "All tests completed successfully."

start:		## Start LocalStack (blocks until ready; image tag configured in .lstk/config.toml)
	@echo "Starting LocalStack..."
	@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) lstk start
	@echo "LocalStack started successfully."

stop:		## Stop the Running LocalStack container
	@echo "Stopping LocalStack..."
	lstk stop

ready:		## Confirm LocalStack is ready (lstk start already waits, so this just reports status)
	@lstk status

logs:     ## Save the LocalStack logs in a separate file
	@lstk logs > logs.txt

.PHONY: usage install run start stop ready logs
