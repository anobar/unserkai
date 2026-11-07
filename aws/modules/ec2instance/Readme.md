# EC2 Instance

The module provides an AWS EC2 Instance with most common resources around.

## ec2 instance subnet relocation
To relocate an ec2 instance from one availability zone to a random one is now (from v0.4.0 ) possible. But this works only if the ec2 instance has no persisted storage or any kind of local state.

- use variable subnet_ids instead of subnet_id.
- run `terraform taint <module instance name>.random_id.index`
- run `terraform apply` and check in the output if the availability zone changes.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.14 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.46.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.46.0 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.enable-ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_key_pair.ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_route53_record.ec2private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ec2public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [random_id.index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_ami.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.s3_bucket_access_software](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_name_pattern"></a> [ami\_name\_pattern](#input\_ami\_name\_pattern) | pattern for ami name | `string` | `""` | no |
| <a name="input_ami_owner"></a> [ami\_owner](#input\_ami\_owner) | ami owner to limit search | `string` | `"099720109477"` | no |
| <a name="input_dns_name"></a> [dns\_name](#input\_dns\_name) | override generated dns name | `any` | `null` | no |
| <a name="input_ec2_ami_id"></a> [ec2\_ami\_id](#input\_ec2\_ami\_id) | (Optional) - id of the ami | `any` | `null` | no |
| <a name="input_ec2_role_policy_attachments"></a> [ec2\_role\_policy\_attachments](#input\_ec2\_role\_policy\_attachments) | iam policy attachments for ec2 role | `list(string)` | `[]` | no |
| <a name="input_ec2_tags"></a> [ec2\_tags](#input\_ec2\_tags) | additional ec2 tags | `map(any)` | `{}` | no |
| <a name="input_firewall_rules"></a> [firewall\_rules](#input\_firewall\_rules) | list of firewall rules | `list(map(string))` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | ec2 instance type | `string` | `"t3.micro"` | no |
| <a name="input_name"></a> [name](#input\_name) | identifier for a lot of resources | `string` | `"this"` | no |
| <a name="input_route53_private_hostedzone_id"></a> [route53\_private\_hostedzone\_id](#input\_route53\_private\_hostedzone\_id) | Route53 Zone ID for private hosted zone | `string` | `""` | no |
| <a name="input_route53_public_hostedzone_id"></a> [route53\_public\_hostedzone\_id](#input\_route53\_public\_hostedzone\_id) | Route53 Zone ID for public hosted zone | `string` | `""` | no |
| <a name="input_s3_bucket_software_arn"></a> [s3\_bucket\_software\_arn](#input\_s3\_bucket\_software\_arn) | n/a | `any` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | ssh public key | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | id of the subnet, overrides random chosen one from subnet\_ids | `string` | `""` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | list of subnet ids, one subnet\_id is chosen per random | `list(string)` | `[]` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | User data to provide when launching the instance. | `string` | `null` | no |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Size of the volume in gibabytes (GiB) | `number` | `50` | no |
| <a name="input_volume_tags"></a> [volume\_tags](#input\_volume\_tags) | ec2 volume\_tags | `map(any)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | id of the vpc | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zone"></a> [availability\_zone](#output\_availability\_zone) | availability zone used for the ec2 instance |
| <a name="output_aws_iam_role"></a> [aws\_iam\_role](#output\_aws\_iam\_role) | n/a |
| <a name="output_aws_instance"></a> [aws\_instance](#output\_aws\_instance) | n/a |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | n/a |
| <a name="output_public_fqdn"></a> [public\_fqdn](#output\_public\_fqdn) | n/a |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | subnet\_id used for the ec2 instance |
<!-- END_TF_DOCS -->
