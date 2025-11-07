pipeline {
    agent any

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

        stage('Deploy ELK Stack') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        EC2_IP=$(terraform -chdir=terraform output -raw public_ip)
                        echo "Deploying ELK stack on $EC2_IP"

                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" docker-compose.yml ec2-user@$EC2_IP:/home/ec2-user/
                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" logstash.conf ec2-user@$EC2_IP:/home/ec2-user/
                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" -r sample-app ec2-user@$EC2_IP:/home/ec2-user/

                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ec2-user@$EC2_IP "sudo docker-compose up -d --build"
                    '''
                }
            }
        }

        stage('Validate') {
            steps {
                sh '''
                EC2_IP=$(terraform -chdir=terraform output -raw public_ip)
                echo "Kibana available at: http://$EC2_IP:5601"
                '''
            }
        }
    }
}
