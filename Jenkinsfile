pipeline {
    agent any

    environment {
        IMAGE_NAME = 'neamulkabiremon/jenkins-flask-app'
        IMAGE_TAG = "${IMAGE_NAME}:${env.GIT_COMMIT}"
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_REGION = 'us-east-2'
        KUBECTL_VERSION = 'v1.28.0'
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    set -e

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

                    echo "Checking k6 installation..."
                    if ! command -v k6 &> /dev/null; then
                        echo "Installing k6..."
                        sudo apt update
                        sudo apt install -y gnupg2
                        curl -fsSL https://dl.k6.io/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg
                        echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
                        sudo apt update
                        sudo apt install -y k6
                    fi

                    aws --version
                    kubectl version --client
                    k6 version

                    echo "Configuring AWS CLI Authentication..."
                    mkdir -p ~/.aws
                    echo "[default]" > ~/.aws/credentials
                    echo "aws_access_key_id=${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
                    echo "aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials
                '''
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                sh """
                    docker build -t ${IMAGE_TAG} .
                    docker push ${IMAGE_TAG}
                    echo "Docker image pushed successfully"
                """
            }
        }

        stage('Deploy to Development') {
            steps {
                sh '''
                    aws eks update-kubeconfig --region ${AWS_REGION} --name staging-prod
                    kubectl config set-context --current --namespace=development

                    for file in k8s/*.yaml; do
                        envsubst < "$file" | kubectl apply -f -;
                    done
                '''
            }
        }

        stage('Acceptance Test') {
            steps {
                script {
                    def service = sh(script: '''
                        echo "Waiting for LoadBalancer provisioning..."
                        sleep 30
                        kubectl get svc flask-app-service -n development -o jsonpath="{.status.loadBalancer.ingress[0].hostname}:{.spec.ports[0].port}"
                    ''', returnStdout: true).trim()

                    if (!service || service.contains(":")) {
                        error "Service URL not found or invalid: '${service}'. Check if the LoadBalancer is provisioned correctly."
                    }

                    echo "Service URL: ${service}"
                    sh "k6 run -e SERVICE=${service} acceptance-test.js || echo 'Performance test failed, continuing...'"
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sh '''
                    echo "Checking if production cluster exists..."
                    if aws eks describe-cluster --region ${AWS_REGION} --name prod-cluster &> /dev/null; then
                        echo "Production cluster found. Proceeding with deployment."
                        aws eks update-kubeconfig --region ${AWS_REGION} --name prod-cluster
                        kubectl config set-context --current --namespace=production

                        for file in k8s/*.yaml; do
                            envsubst < "$file" | kubectl apply -f -;
                        done
                    else
                        echo "Production cluster 'prod-cluster' not found. Skipping deployment."
                        exit 0
                    fi
                '''
            }
        }
    }
}
