# Kinetic Bridgehub Adapter Amazon EC2
This bridge adapter is used for interacting with the AWS EC2 endpoints

## Configuration Values

| Name                    | Description | Example Value |
| :---------------------- | :------------------------- | :------------------------- |
| Access Key        | Access Keys are used to sign the requests you send to Amazon S3. | AKIA7997DFLK907DIV |
| Secret Key        | An AWS key similar to a private key. | 6+2werFvwetjou+jklsjdfgu93jg4gf4 |
| Endpoint          | The URL that serves as the entry point for the web service. For more information, see [Amazon EC2 service endpoints](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/Using_Endpoints.html). | https://service.region.amazonaws.com |
| Host              | |
| Region            | AWS has the concept of a Region, which is a physical location around the world where we cluster data centers. | us-east-1 | 
| Action            | The action that you want to perform. | RunInstances |
| API Version       | The API version to use. | 2016-11-15. |
