package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	repoROOT      = "../terraform/aws/rancher/"
	publicDomain  = ""
	assumeRoleArn = ""
)

//const savedAwsRegion = "AwsRegion"

func getRandomAwsRegion(t *testing.T) string {
	excludedRegions := []string{
		"us-east-2",
	}
	return aws.GetRandomRegion(t, nil, excludedRegions)
}

// An example of how to test the Terraform module in examples/terraform-http-example using Terratest.
func runRancherTest(t *testing.T) {
	// Run test in a different Dir
	tmpDir := test_structure.CopyTerraformFolderToTemp(t, repoROOT, ".")

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, tmpDir)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		// Pick a random AWS region to test in. This helps ensure your code works in all regions.
		awsRegion := getRandomAwsRegion(t)
		//test_structure.SaveString(t, tmpDir, savedAwsRegion, awsRegion)
		// A unique ID we can use to namespace resources so we don't clash with anything already in the AWS account or
		// tests running in parallel
		uniqueID := random.UniqueId()
		// Give this EC2 Instance and other resources in the Terraform code a name with a unique ID so it doesn't clash
		// with anything else in the AWS account.
		uniqueName := fmt.Sprintf("rancher-%s", uniqueID)

		terraformOptions := &terraform.Options{
			// The path to where our Terraform code is located
			TerraformDir: tmpDir,

			// Variables to pass to our Terraform code using -var options
			Vars: map[string]interface{}{
				"aws_region":      awsRegion,
				"unique_name":     uniqueName,
				"public_domain":   publicDomain,
				"assume_role_arn": assumeRoleArn,
			},
		}
		test_structure.SaveTerraformOptions(t, tmpDir, terraformOptions)
		// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, tmpDir)
		// Run `terraform output` to get the value of an output variable
		instanceURL := terraform.Output(t, terraformOptions, "instance_url")
		// Verify that we get back a 200 OK with the expected instanceText
		http_helper.HttpGet(t, instanceURL)
	})
}
