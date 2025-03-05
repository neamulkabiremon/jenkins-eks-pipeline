pipeline {
    agent any

    environment {
        IMAGE_NAME = 'neamulkabiremon/jenkins-flask-app'
        IMAGE_TAG = "${IMAGE_NAME}:${env.GIT_COMMIT}"
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_REGION = 'us-east-2'
        KUBECTL_VERSION = 'v1.28.0'  // ✅ Manually specify a stable version
        KUBECONFIG = '/var/lib/jenkins/.kube/config'  // ✅ Ensure config is persisted
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
                        sudo ./aws/install --update
                        rm -rf awscliv2.zip aws
                    fi

                    echo "Checking kubectl installation..."
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/
                    fi

                    # Verify installations
                    aws --version
                    kubectl version --client

                    echo "Configuring AWS CLI Authentication..."
                    aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                    aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                    aws configure set region ${AWS_REGION}
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

                    echo "Authenticating with AWS EKS..."
                    aws eks update-kubeconfig --region ${AWS_REGION} --name staging-prod

                    echo "Setting Kubernetes namespace to 'development'..."
                    kubectl config set-context --current --namespace=development

                    echo "Ensuring EKS authentication..."
                    aws eks get-token --region ${AWS_REGION} --cluster-name staging-prod

                    echo "Deploying to Kubernetes (namespace: development)..."
                    kubectl apply -f k8s
                '''
            }
        }

        stage('Acceptance Test') {
            steps {
                script {
                    def service = sh(script: "kubectl get svc flask-app-service -n development -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:{.spec.ports[0].port}'", returnStdout: true).trim()
                    echo "Service URL: ${service}"
                    sh "k6 run -e SERVICE=${service} acceptance-test.js"
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sh '''
                    export PATH=$PATH:/usr/local/bin

                    echo "Switching to Production EKS Cluster..."
                    aws eks update-kubeconfig --region ${AWS_REGION} --name prod-cluster

                    echo "Setting Kubernetes namespace to 'production'..."
                    kubectl config set-context --current --namespace=production

                    echo "Verifying current Kubernetes context..."
                    kubectl config current-context

                    echo "Ensuring EKS authentication..."
                    aws eks get-token --region ${AWS_REGION} --cluster-name prod-cluster

                    echo "Deploying to Production..."
                    kubectl set image deployment/flask-app flask-app=${IMAGE_TAG} -n production
                '''
            }
        }
    }
}
