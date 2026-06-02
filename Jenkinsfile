pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
    IMAGE_NAME = 'elhalawany-devops-app:latest'
    LOCAL_IMAGE = 'elhalawany-devops-app:latest'
    GHCR_IMAGE = 'ghcr.io/jcsa2030/elhalawany-devops-lab:v1.0.0-devsecops-lab'
    DEPLOY_IMAGE = 'ghcr.io/jcsa2030/elhalawany-devops-lab:security'
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

stage('GitLeaks Secret Scan') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            sh '''
            mkdir -p security-reports/gitleaks

            gitleaks detect \
              --source . \
              --redact \
              --report-format json \
              --report-path security-reports/gitleaks/gitleaks-report.json
            '''
        }
    }
}


stage('Generate SBOM with Syft') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            sh '''
            mkdir -p security-reports/sbom
            syft . -o cyclonedx-json > security-reports/sbom/sbom-cyclonedx.json
            '''
        }
    }
}

                stage('Upload SBOM to Dependency-Track') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    withCredentials([string(credentialsId: 'vault-jenkins-token', variable: 'VAULT_TOKEN')]) {
                        sh '''
                        set +x

                        echo "Reading Dependency-Track API key from Vault..."

                        DTRACK_API_KEY=$(curl -s \
                          -H "X-Vault-Token:$VAULT_TOKEN" \
                          http://127.0.0.1:8200/v1/secret/data/devsecops/dependency-track \
                          | jq -r '.data.data.API_KEY')

                        if [ -z "$DTRACK_API_KEY" ] || [ "$DTRACK_API_KEY" = "null" ]; then
                            echo "ERROR: Dependency-Track API key not found in Vault"
                            exit 1
                        fi

                        echo "Uploading SBOM to Dependency-Track..."

                        curl -s -X POST \
                          http://localhost:8085/api/v1/bom \
                          -H "X-Api-Key: $DTRACK_API_KEY" \
                          -F "autoCreate=true" \
                          -F "projectName=elhalawany-devops-lab" \
                          -F "projectVersion=security" \
                          -F "bom=@security-reports/sbom/sbom-cyclonedx.json" >/dev/null

                        unset DTRACK_API_KEY

                        echo "SBOM upload submitted successfully."
                        '''
                    }
                }
            }
        }
        
stage('OPA Policy Gate') {
    steps {
        sh '''
        echo "Running OPA policy validation..."

        opa eval \
          --format pretty \
          --data policies/opa/devsecops-policy.rego \
          --input policies/opa/input.json \
          "data.devsecops.deny" | tee policies/opa/opa-result.txt

        if grep -q "Docker image tag must not be latest\\|Production deployment requires approval\\|Security headers must be enabled\\|Trivy scan must be enabled" policies/opa/opa-result.txt; then
            echo "OPA policy violations found."
            cat policies/opa/opa-result.txt
            exit 1
        fi

        echo "OPA policy validation passed."
        '''
    }
}

                stage('SonarQube SAST') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    withSonarQubeEnv("${SONARQUBE_SERVER}") {
                        sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=elhalawany-devops-lab \
                          -Dsonar.projectName="Elhalawany DevOps Lab" \
                          -Dsonar.sources=. \
                          -Dsonar.sourceEncoding=UTF-8 \
                          -Dsonar.nodejs.executable=/usr/local/opt/node@20/bin/node \
                          -Dsonar.exclusions=index.js,node_modules/**,coverage/**,dist/**,build/**,.scannerwork/**,compliance/**,scripts/**,security-reports/**,zap-reports/**,*.csv,*.json
                        '''
                    }
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 3, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
                        stage('Trivy Filesystem Scan') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh '''
                    mkdir -p security-reports/trivy

                    trivy fs \
                      --scanners vuln,secret,misconfig \
                      --severity HIGH,CRITICAL \
                      --format table \
                      --output security-reports/trivy/trivy-fs-report.txt \
                      .

                    trivy fs \
                      --scanners vuln,secret,misconfig \
                      --severity HIGH,CRITICAL \
                      --format json \
                      --output security-reports/trivy/trivy-fs-report.json \
                      .
                    '''
                }
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
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh '''
                    mkdir -p security-reports/trivy

                    trivy image \
                      --severity HIGH,CRITICAL \
                      --format table \
                      --output security-reports/trivy/trivy-image-report.txt \
                      ${IMAGE_NAME}

                    trivy image \
                      --severity HIGH,CRITICAL \
                      --format json \
                      --output security-reports/trivy/trivy-image-report.json \
                      ${IMAGE_NAME}
                    '''
                }
            }
        }


                stage('Push Image to GHCR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ghcr-creds',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh '''
                    set -e

                    echo "Logging in to GitHub Container Registry..."
                    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

                    echo "Detecting release version..."
                    VERSION=$(git describe --tags --abbrev=0)

                    echo "Release version detected: $VERSION"

                    echo "Tagging image for GHCR..."
                    docker tag elhalawany-devops-app:latest ghcr.io/jcsa2030/elhalawany-devops-lab:security
                    docker tag elhalawany-devops-app:latest ghcr.io/jcsa2030/elhalawany-devops-lab:${BUILD_NUMBER}
                    docker tag elhalawany-devops-app:latest ghcr.io/jcsa2030/elhalawany-devops-lab:$VERSION

                    echo "Pushing image to GHCR..."
                    docker push ghcr.io/jcsa2030/elhalawany-devops-lab:security
                    docker push ghcr.io/jcsa2030/elhalawany-devops-lab:${BUILD_NUMBER}
                    docker push ghcr.io/jcsa2030/elhalawany-devops-lab:$VERSION

                    echo "GHCR push completed successfully."
                    echo "Published tags:"
                    echo "- security"
                    echo "- ${BUILD_NUMBER}"
                    echo "- $VERSION"
                    '''
                }
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
                withCredentials([usernamePassword(
                    credentialsId: 'ghcr-creds',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh '''
                    set -e

                    echo "Deploying application with GHCR primary and local fallback..."

                    echo "Logging in to GHCR..."
                    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

                    echo "Trying to pull GHCR image: ${DEPLOY_IMAGE}"
                    if docker pull ${DEPLOY_IMAGE}; then
                        echo "GHCR image pulled successfully."
                        APP_IMAGE=${DEPLOY_IMAGE}
                    else
                        echo "WARNING: GHCR pull failed. Falling back to local image: ${LOCAL_IMAGE}"
                        APP_IMAGE=${LOCAL_IMAGE}
                    fi

                    export APP_IMAGE

                    echo "Using deployment image: $APP_IMAGE"

                    echo "Stopping old application stack..."
                    docker compose down --remove-orphans || true

                    echo "Starting application stack..."
                    docker compose up -d

                    echo "Current running containers:"
                    docker ps
                    '''
                }
            }
        }
                
        stage('Health Check') {
            steps {
                sh '''
                set -e

                echo "Waiting for services to start..."
                sleep 25

                echo "Checking main application..."
                curl -f http://localhost:8080/health

                echo "Checking PostgreSQL..."
                curl -f http://localhost:8080/api/db-health

                echo "Checking Redis..."
                curl -f http://localhost:8080/api/redis-health

                echo "Checking Customers API..."
                curl -f http://localhost:8080/api/customers-invalid

                echo "Health check passed successfully."
                '''
            }
            post {
                failure {
                    sh '''
                    echo "Health check failed. Starting automated rollback..."

                    chmod +x rollback-devsecops.sh

                    ./rollback-devsecops.sh v1.0.1-devsecops-lab

                    echo "Automated rollback completed."
                    '''
                }
            }
        }
    }
}
