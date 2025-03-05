# Jenkins EKS Pipeline

## Overview
This project sets up a **CI/CD pipeline** using **Jenkins** to deploy a Flask application on **Amazon Elastic Kubernetes Service (EKS)**. It automates **building, testing, and deploying** the application to Kubernetes.

## Features
- **Jenkins Pipeline** for CI/CD automation
- **Dockerized Flask application**
- **Kubernetes (EKS) Deployment**
- **Helm Charts (Optional)**
- **Ingress with ALB Controller**
- **Automated Testing using PyTest**
- **IAM Policies for AWS Access**

## Prerequisites
Before running this project, ensure you have:
- **Jenkins** installed with required plugins
- **Docker** installed and running
- **AWS CLI** configured with IAM permissions
- **kubectl** installed and configured for EKS
- **Helm (Optional)**
- **Python 3 & Poetry (for dependency management)**
