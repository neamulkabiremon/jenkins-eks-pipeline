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
                    set -e  # Exit immediately if a command exits with a non-zero status
                    
                    # Install or update AWS CLI
                    if command -v aws &> /dev/null; then
                        echo "AWS CLI is already installed. Updating..."
                        sudo ./aws/install --update
                    else
                        echo "AWS CLI not found. Installing..."
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip awscliv2.zip
                        sudo ./aws/install
                        rm -rf awscliv2.zip aws
                    fi

                    # Install kubectl if not installed
                    if ! command -v kubectl &> /dev/null; then
                        echo "kubectl not found. Installing..."
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/
                    else
                        echo "kubectl is already installed"
                    fi

                    # Verify installations
                    aws --version
                    kubectl version --client

                    # Ensure Python dependencies are installed
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
                   echo "Docker image build successfully"
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
                    aws --version
                    kubectl version --client
                    aws eks update-kubeconfig --region us-east-2 --name staging-prod
                    kubectl config current-context
                    kubectl set image deployment/flask-app flask-app=${IMAGE_TAG}
                '''
            }
        }

        stage('Acceptance Test') {
            steps {
                script {
                    def service = sh(script: "kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:{.spec.ports[0].port}'", returnStdout: true).trim()
                    echo "${service}"
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
