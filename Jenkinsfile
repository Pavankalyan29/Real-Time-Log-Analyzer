pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        REPO_NAME = "real-time-log-analyzer"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Pavankalyan29/Real-Time-Log-Analyzer.git'
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                dir('terraform') {
                    sh '''
                    terraform init
                    terraform apply -auto-approve
                    '''
                }
            }
        }

        stage('Build & Push to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh '''
                        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        REPO_URI=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME

                        # Authenticate Docker to ECR
                        echo "Logging into ECR..."
                        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URI

                        # Build and push image
                        echo "Building and pushing Docker image..."
                        docker build -t $REPO_NAME:latest sample-app/
                        docker tag $REPO_NAME:latest $REPO_URI:latest
                        docker push $REPO_URI:latest
                    '''
                }
            }
        }

        stage('Deploy ELK Stack') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        EC2_IP=$(terraform -chdir=terraform output -raw public_ip)
                        echo "Deploying ELK stack on $EC2_IP"

                        # Fix Windows SSH key permissions
                        icacls "$SSH_KEY" /inheritance:r
                        icacls "$SSH_KEY" /grant:r "SYSTEM:R"
                        icacls "$SSH_KEY" /grant:r "Administrators:R"

                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" docker-compose.yml ec2-user@$EC2_IP:/home/ec2-user/
                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" logstash.conf ec2-user@$EC2_IP:/home/ec2-user/

                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ec2-user@$EC2_IP '
                          set -e
                          REGION="ap-south-1"
                          ACCOUNT_ID="108792016419"
                          echo "🔹 Logging into ECR on EC2..."
                          aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
                          echo "🔹 Launching ELK stack..."
                          sudo docker-compose up -d
                          echo "✅ Containers deployed successfully."
                          sudo docker ps
                        '
                    '''
                }
            }
        }

        stage('Validate') {
            steps {
                sh '''
                EC2_IP=$(terraform -chdir=terraform output -raw public_ip)
                echo "✅ Kibana available at: http://$EC2_IP:5601"
                '''
            }
        }
    }
}
