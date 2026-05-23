pipeline {
    agent any

    environment {
        IMAGE_NAME = 'elhalawany-devops-app:latest'
        SONARQUBE_SERVER = 'SonarQube'
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

        stage('Deploy') {
            steps {
                sh 'docker compose down || true'
                sh 'docker compose up -d --build'
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                sleep 15
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
