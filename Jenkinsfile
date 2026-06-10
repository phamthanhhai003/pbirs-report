pipeline {
    agent { label 'windows' }

    environment {
        PBIRS_HOST = 'http://192.168.100.98/reports'
        PBIRS_USER = credentials('pbirs-user')
        PBIRS_PASS = credentials('pbirs-pass')
    }

    stages {
        stage('Deploy to PBIRS') {
            steps {
                bat 'powershell -ExecutionPolicy Bypass -File scripts/upload_pbirs.ps1'
            }
        }
    }

    post {
        success { echo 'Deployed successfully' }
        failure  { echo 'Deploy failed' }
    }
}
