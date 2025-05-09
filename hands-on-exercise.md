# DevOps Hands-On Exercise (1 Hour)

## Objective

Provision infrastructure using Terraform, build and push a containerized Node.js app to AWS ECR, and deploy it to AWS ECS Fargate using GitHub Actions.

## Prerequisites

- GitHub account
- AWS account (free tier if available) or use localstack for AWS emulation

## Exercise Tasks

### Part 1: Terraform Setup (30 minutes)

1. Create a new directory for Terraform configuration:

   ```bash
   mkdir terraform
   cd terraform
   ```

2. Create the following Terraform files:

   - `main.tf`: Define AWS provider and basic VPC
   - `variables.tf`: Define input variables
   - `outputs.tf`: Define output values

3. Implement basic infrastructure:
   - VPC with public subnet
   - Security group for the application
   - ECS cluster (Fargate)
   - Task definition for Fargate

### Part 2: GitHub Actions Setup (30 minutes)

1. Create `.github/workflows` directory:

   ```bash
   mkdir -p .github/workflows
   ```

2. Create a CI/CD workflow file:
   - Build and push Docker image
   - Deploy to AWS

## Expected Deliverables

1. Github repo with Terraform that deploys app to LocalStack ECS Fargate or AWS Fargate
2. GitHub Action workflow that builds & deploys on commit
3. README.md with instruction to deploy & test the service

## Bonus Tasks (if time permits)

1. Add environment variables to make the PORT configurable
2. Configure container autoscaling
