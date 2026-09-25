pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        APP_DIR = 'app'
        APP_HEALTH_URL = 'http://127.0.0.1/health'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install dependencies') {
            steps {
                dir("${APP_DIR}") {
                    sh 'npm ci'
                }
            }
        }

        stage('Build') {
            steps {
                dir("${APP_DIR}") {
                    sh 'npm run build'
                }
            }
        }

        stage('Test') {
            steps {
                dir("${APP_DIR}") {
                    sh 'npm test'
                }
            }
        }

        stage('Deploy') {
            steps {
                sh 'bash scripts/deploy-app.sh "$WORKSPACE/$APP_DIR"'
            }
        }

        stage('Health check') {
            steps {
                sh 'bash scripts/health-check.sh "$APP_HEALTH_URL"'
            }
        }
    }
}