Prerequisites Before you begin, make sure you have the following:

An AWS account Terraform installed on your local machine AWS CLI installed on your local machine

Step 1: Configure AWS CLI To configure AWS CLI, follow these steps:

Open a terminal window on your local machine. Run the command aws configure. Enter your AWS access key ID and secret access key when prompted. Set the default region name to the region you want to create your infrastructure in. Set the default output format to json.

Step 2: Set up Terraform To set up Terraform, follow these steps:

Download the latest version of Terraform from the official website. Install Terraform on your local machine. Verify the installation by running the command terraform --version.

Step 3: Create an IAM user and access keys To create an IAM user and access keys, follow these steps:

Log in to your AWS account. Navigate to the IAM dashboard. Click on "Users" in the left-hand menu. Click on the "Add user" button. Enter a name for the user and select "Programmatic access". Click on the "Next: Permissions" button. Select "Attach existing policies directly". Search for and select the "AdministratorAccess" policy. Click on the "Next: Tags" button. Click on the "Next: Review" button. Review the user's settings and click on the "Create user" button. Save the access key ID and secret access key somewhere secure.

Step 4: Write Terraform code To write Terraform code to create your infrastructure, follow these steps:

Create a new directory for your Terraform code. Create a new file called main.tf. Add your AWS access key ID and secret access key to your Terraform code as environment variables. Alternatively, you can set them as variables in a separate file and reference them in your Terraform code. Define the resources you want to create in your main.tf file, such as EC2 instances, security groups, or VPCs. Save your main.tf file.

Step 5: Initialize and apply Terraform code To initialize and apply your Terraform code, follow these steps:

Open a terminal window and navigate to your Terraform code directory. Run the command terraform init to initialize your Terraform code. Run the command terraform plan to see what changes Terraform will make to your infrastructure. Run the command terraform apply to apply your Terraform code and create your infrastructure. Review the output to make sure there are no errors. 
Step 6: Destroy the infrastructure To destroy the infrastructure you created, run the command terraform destroy. This will remove all resources created by your Terraform code.

Command to import the certificate :

aws acm import-certificate --certificate fileb://path --certificate-chain fileb://path --private-key fileb://path --profile demo






