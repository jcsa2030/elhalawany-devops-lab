pipeline {
    agent any

    environment {
        IMAGE_NAME = 'elhalawany-devops-app:latest'
        SONARQUBE_SERVER = 'SonarQube'
        PATH = "/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin:${env.PATH}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('Validate JavaScript') {
            steps {
                sh 'node -c index.js'
            }
        }

        stage('SonarQube SAST') {
            steps {
                withSonarQubeEnv("${SONARQUBE_SERVER}") {
                    sh '''
                    sonar-scanner \
                      -Dsonar.projectKey=elhalawany-devops-lab \
                      -Dsonar.projectName="Elhalawany DevOps Lab" \
                      -Dsonar.sources=. \
                      -Dsonar.exclusions=node_modules/**,coverage/**,dist/**,build/**
                    '''
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                trivy fs \
                  --scanners vuln,secret,misconfig \
                  --severity HIGH,CRITICAL \
                  --exit-code 0 \
                  .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t ${IMAGE_NAME} .'
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                trivy image \
                  --severity HIGH,CRITICAL \
                  --exit-code 0 \
                  ${IMAGE_NAME}
                '''
            }
        }

        stage('Create Environment File') {
            steps {
                sh '''
                cat > .env.dev <<EOF
APP_NAME=Elhalawany Dev Environment
APP_ENV=dev
PORT=3000
APP_COLOR=#38bdf8
APP_MESSAGE=Development Environment - Jenkins CI/CD Deployment

DB_HOST=postgres
DB_PORT=5432
DB_NAME=devopsdb
DB_USER=devopsuser
DB_PASSWORD=devopspassword

REDIS_HOST=redis
REDIS_PORT=6379
EOF

                echo "Checking .env.dev file:"
                ls -la .env.dev
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                echo "Current workspace:"
                pwd

                echo "Verify env file before deployment:"
                ls -la .env.dev

                docker compose down || true
                docker compose up -d --build
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                sleep 20
                curl -f http://localhost:8080/health
                curl -f http://localhost:8080/api/db-health
                curl -f http://localhost:8080/api/redis-health
                '''
            }
        }
    }

    post {
        success {
            echo 'DevSecOps Pipeline completed successfully.'
        }

        failure {
            echo 'DevSecOps Pipeline failed.'
        }

        always {
            echo 'Pipeline finished.'
        }
    }
}