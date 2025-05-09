## DEMO

### Terraform 

- Resources Created
    - VPC
    - 3 Private Subnets
    - 3 Public Subnets
    - Nat Gateway
    - Internet Gateway
    - Route
    - Subnet Association to Route
    - ECS Service
    - ECS task Definations
    - AWS ALB
    - Scaling Policy based on CPU
    - Scaling Policy based on Memory


### Github Actions Setup

1. Fork the repo
2. Setup github secrets
    - DOCKER_USERNAME
    - DOCKER_PASSWORD
    - DOCKER_IMAGE
    - AWS_ACCESS_KEY
    - AWS_SECRET_ACCESS_KEY
    - AWS_REGION

3. Github actions should trigger on the push to main

### Extra

Variables defined on the terraform can be used to change the config like cidr, tags, ecs name, ecs port.