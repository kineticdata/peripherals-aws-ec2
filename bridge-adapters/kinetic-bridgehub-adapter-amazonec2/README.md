# Kinetic Bridgehub Adapter Amazon EC2
This bridge adapter is used for interacting with the AWS EC2 endpoints

## Configuration Values
| Name                   | Description | Example Value |
| :---------------------- | :------------------------- | :------------------------- |
| Access Key        | Access Keys are used to sign the requests you send to Amazon S3. | AKIA7997DFLK907DIV |
| Secret Key        | An AWS key similar to a private key. | 6+2werFvwetjou+jklsjdfgu93jg4gf4 |
| Region          | The URL that serves as the entry point for the web service. For more information, see [Amazon EC2 service endpoints](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/Using_Endpoints.html). | us-east-1 |

## Supported Structures
* The adapter appends the structure to a query parameter **Describe** to make a request for an aws [Action](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_Operations.html)

| Name      | Description                                         | Output Action Parameter Value |
|:----------|:----------------------------------------------------|:------------------------------|
| Instances | Describes the specified instances or all instances. | DescribeInstances             |

## Attributes and Fields
* If no fields are provided then all fields will be returned.

## Qualifications (Query)
* For each structure AWS supports different query options.  Find the **Describe...** in the [Action](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_Operations.html) for details.
  * Add `MaxResults=10` to the query so that the number of instances will be limited to 10
  * To perform a 


## Notes
* The bridge adapter is hard coded to add `Version=2016-11-15` as a query parameter
* The bridge adapter is hard coded to make requests to `https://ec2.amazonaws.com`
* The adapter does not support retrieving the nextToken parameter