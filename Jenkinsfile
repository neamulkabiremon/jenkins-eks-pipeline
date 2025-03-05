pipeline {
    agent any

    environment {
        IMAGE_NAME = 'neamulkabiremon/jenkins-flask-app'
        IMAGE_TAG = "${IMAGE_NAME}:${env.GIT_COMMIT}"
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_REGION = 'us-east-2'
        EKS_CLUSTER_NAME = 'staging-prod'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    echo 'Installing AWS CLI and kubectl...'
                    sh """
                    apt-get update && apt-get install -y awscli
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/
                    """
                    
                    echo 'Authenticating with EKS...'
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}"
                    
                    echo 'Installing dependencies...'
                    sh "pip install -r requirements.txt"
                }
            }
        }

        stage('Test') {
            steps {
                sh "pytest"
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-creds', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh 'echo ${PASSWORD} | docker login -u ${USERNAME} --password-stdin'
                }
                echo 'Login successfully'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${IMAGE_TAG} .'
                echo "Docker image built successfully"
                sh 'docker image ls'
            }
        }

        stage('Push Docker Image') {
            steps {
                sh 'docker push ${IMAGE_TAG}'
                echo "Docker image pushed successfully"
            }
        }

        stage('Deploy to Development') {
            steps {
                script {
                    echo 'Deploying to Development...'
                    sh "kubectl set image deployment/flask-app flask-app=${IMAGE_TAG}"
                }
            }
        }

        stage('Acceptance Test') {
            steps {
                script {
                    def service = sh(script: "kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:{.spec.ports[0].port}'", returnStdout: true).trim()
                    echo "Running acceptance tests against ${service}"
                    sh "k6 run -e SERVICE=${service} acceptance-test.js"
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                script {
                    echo 'Deploying to Production...'
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name prod-cluster"
                    sh "kubectl set image deployment/flask-app flask-app=${IMAGE_TAG}"
                }
            }
        }
    }
}
