pipeline {
    agent { label 'windows' }

    environment {
        PBIRS_HOST = 'http://DESKTOP-HHC5U09/reports'
        PBIRS_USER = credentials('pbirs-user')
        PBIRS_PASS = credentials('pbirs-pass')
    }

    stages {
        stage('Compile') {
            steps {
                bat 'pbi-tools compile ./source -outPath CreditReport.pbix -overwrite'
            }
        }

        stage('Deploy to PBIRS') {
            steps {
                bat 'python scripts/deploy_pbirs.py CreditReport.pbix'
            }
        }
    }

    post {
        success { echo 'Deployed successfully' }
        failure  { echo 'Deploy failed' }
    }
}
