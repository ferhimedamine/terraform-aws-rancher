# terraform-aws-rancher
Rancher on AWS Terraform Module

# Requirements
 - AWS Account and IAM credentials
 - AWS Route53 DNS Zone
 - Terraform v0.11.7

# Setup
rename variables.tf.example to variables.tf.

# Run
```bash
terraform init
terraform plan
terraform apply
```

# Tests

All of the tests are written in Go. Most of these are "integration tests" that deploy real infrastructure using Terraform and verify that infrastructure works as expected using a helper library called [Terratest](https://github.com/gruntwork-io/terratest).

### Download Go dependencies using dep:
```bash
cd test
dep ensure
```

### Run all tests:
```bash
cd test
go test -v -timeout 60m
```

### Run a specific test
```bash
cd test
go test -V -timeout 60 -run TestFoo
```