# terraform-aws-rancher
Rancher on AWS Terraform Module

# Requirements
 - AWS Account and IAM credentials
 - AWS Route53 DNS Zone with public domain
 - Terraform v0.11.7

Add the [terraform-provider-ct](https://github.com/coreos/terraform-provider-ct) plugin binary for your system.

```
wget https://github.com/coreos/terraform-provider-ct/releases/download/v0.3.0/terraform-provider-ct-v0.3.0-linux-amd64.tar.gz
tar xzf terraform-provider-ct-v0.3.0-linux-amd64.tar.gz
sudo mv terraform-provider-ct-v0.3.0-linux-amd64/terraform-provider-ct /usr/local/bin/
```

Add the plugin to your `~/.terraformrc`.

```hcl
providers {
  ct = "/usr/local/bin/terraform-provider-ct"
}
```

# Setup
rename rancher.tf.example to rancher.tf.

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