pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_NAME = 'elhalawany-devops-app:latest'
        SONARQUBE_SERVER = 'SonarQube'
        PATH = "/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin:${env.PATH}"
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub...'
                checkout scm
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                echo "Verifying required tools..."
                node --version
                npm --version
                docker --version
                docker compose version
                sonar-scanner --version
                trivy --version
                '''
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

        stage('SonarQube SAST - Fixed Non Blocking') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            timeout(time: 5, unit: 'MINUTES') {
                withSonarQubeEnv("${SONARQUBE_SERVER}") {
                    sh '''
                    sonar-scanner \
                      -Dsonar.projectKey=elhalawany-devops-lab \
                      -Dsonar.projectName="Elhalawany DevOps Lab" \
                      -Dsonar.sources=. \
                      -Dsonar.sourceEncoding=UTF-8 \
                      -Dsonar.nodejs.executable=/usr/local/opt/node@20/bin/node \
                      -Dsonar.exclusions=index.js,node_modules/**,coverage/**,dist/**,build/**,.scannerwork/**,compliance/**,scripts/**,*.csv,*.json
                    '''
                }
            }
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
                sh '''
                echo "Building Docker image..."
                docker build -t ${IMAGE_NAME} .
                '''
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

        stage('Production Approval') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input(
                        message: 'Approve deployment to the lab production environment?',
                        ok: 'Deploy',
                        submitter: 'prod1,prod2'
                    )
                }
            }
        }

        stage('Create Environment File') {
            steps {
                sh '''
                cat > .env.dev <<EOF
APP_NAME=Elhalawany Dev Environment
APP_ENV=dev
NODE_ENV=dev
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

LOG_LEVEL=debug
ENABLE_SECURITY_HEADERS=true
ENABLE_CORS=true
EOF

                echo "Environment file created successfully:"
                ls -la .env.dev
                '''
            }
        }

        stage('Cleanup Old Containers') {
            steps {
                sh '''
                echo "Cleaning old containers and compose stack..."
                docker compose down --remove-orphans || true

                docker rm -f elhalawany-redis || true
                docker rm -f elhalawany-postgres || true
                docker rm -f elhalawany-app || true
                docker rm -f elhalawany-nginx || true
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                echo "Deploying application using Docker Compose..."
                docker compose up -d --build
                docker ps
                '''
            }
        }

stage('OWASP ZAP DAST Scan') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            timeout(time: 15, unit: 'MINUTES') {
                sh '''
                echo "Starting OWASP ZAP Baseline Scan..."

                mkdir -p zap-reports

                docker run --rm \
                  -v "$(pwd)/zap-reports:/zap/wrk:rw" \
                  -t ghcr.io/zaproxy/zaproxy:stable \
                  zap-baseline.py \
                  -t http://host.docker.internal:8080 \
                  -r zap-report.html \
                  -J zap-report.json \
                  -I

                echo "OWASP ZAP reports generated:"
                ls -la zap-reports
                '''
            }
        }
    }
}

        stage('Health Check') {
            steps {
                sh '''
                echo "Waiting for services to start..."
                sleep 25

                echo "Checking main application..."
                curl -f http://localhost:8080/health

                echo "Checking PostgreSQL..."
                curl -f http://localhost:8080/api/db-health

                echo "Checking Redis..."
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
            echo 'DevSecOps Pipeline failed. Review Jenkins logs.'
        }

        always {
            echo 'Pipeline finished.'
        }
    }
}