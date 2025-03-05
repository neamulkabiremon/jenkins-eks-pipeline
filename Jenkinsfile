pipeline {
    agent any

    environment {
        IMAGE_NAME = 'neamulkabiremon/jenkins-flask-app'
        IMAGE_TAG = "${IMAGE_NAME}:${env.GIT_COMMIT}"
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    set -e  # Exit on error

                    echo "Checking AWS CLI installation..."
                    if ! command -v aws &> /dev/null; then
                        echo "Installing AWS CLI..."
                        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -o awscliv2.zip > /dev/null
                        yes | sudo ./aws/install
                        rm -rf awscliv2.zip aws
                    fi

                    echo "Checking kubectl installation..."
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -sLO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/
                    fi

                    # Verify installations
                    aws --version
                    kubectl version --client

                    echo "Configuring AWS Credentials..."
                    mkdir -p ~/.aws
                    cat <<EOT > ~/.aws/credentials
                    [default]
                    aws_access_key_id=${AWS_ACCESS_KEY_ID}
                    aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
                    region=us-east-2
                    EOT

                    # Install dependencies
                    echo "Installing Python dependencies..."
                    pip install --user -r requirements.txt
                    pip install --user pytest
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    export PATH=$HOME/.local/bin:$PATH
                    python -m pytest
                '''
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-creds', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh 'echo $PASSWORD | docker login -u $USERNAME --password-stdin'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                   docker build -t ${IMAGE_TAG} .
                   echo "Docker image built successfully"
                   docker image ls
                """
            }
        }

        stage('Push Docker Image') {
            steps {
                sh "docker push ${IMAGE_TAG}"
                echo "Docker image pushed successfully"
            }
        }

        stage('Deploy to Development') {
            steps {
                sh '''
                    export PATH=$PATH:/usr/local/bin

                    echo "Configuring AWS CLI for authentication..."
                    aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                    aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                    aws configure set region us-east-2

                    echo "Authenticating with EKS..."
                    aws eks update-kubeconfig --region us-east-2 --name staging-prod
                    kubectl config current-context

                    echo "Ensuring EKS authentication..."
                    aws eks get-token --region us-east-2 --cluster-name staging-prod

                    echo "Deploying to EKS..."
                    kubectl set image deployment/flask-app flask-app=${IMAGE_TAG}
                '''
            }
        }

        stage('Acceptance Test') {
            steps {
                script {
                    def service = sh(script: "kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:{.spec.ports[0].port}'", returnStdout: true).trim()
                    echo "Service URL: ${service}"
                    sh "k6 run -e SERVICE=${service} acceptance-test.js"
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sh '''
                    export PATH=$PATH:/usr/local/bin
                    aws eks update-kubeconfig --region us-east-2 --name prod-cluster
                    kubectl config current-context
                    kubectl set image deployment/flask-app flask-app=${IMAGE_TAG}
                '''
            }
        }
    }
}
