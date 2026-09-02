pipeline {
    agent any

    environment {
        API_IMAGE  = 'arunelak/tutorials-api'
        UI_IMAGE   = 'arunelak/tutorials-ui'
        APP_SERVER = 'ubuntu@52.87.175.46'
        APP_URL    = 'http://52.87.175.46'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    docker build -t $API_IMAGE:$BUILD_NUMBER -t $API_IMAGE:latest ./bezkoder-api
                    docker build --build-arg REACT_APP_API_BASE_URL=/api \
                        -t $UI_IMAGE:$BUILD_NUMBER -t $UI_IMAGE:latest ./bezkoder-ui
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_TOKEN'
                )]) {
                    sh '''
                        echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
                        docker push $API_IMAGE:$BUILD_NUMBER
                        docker push $API_IMAGE:latest
                        docker push $UI_IMAGE:$BUILD_NUMBER
                        docker push $UI_IMAGE:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to AWS') {
            steps {
                sshagent(credentials: ['app-server-ssh']) {
                    sh '''
                        scp -o StrictHostKeyChecking=accept-new docker-compose.prod.yml $APP_SERVER:/opt/app/docker-compose.yml
                        ssh -o StrictHostKeyChecking=accept-new $APP_SERVER \
                            "cd /opt/app && docker compose pull -q && docker compose up -d && docker image prune -f"
                    '''
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    sleep 10
                    curl -fsS $APP_URL/ > /dev/null
                    curl -fsS $APP_URL/api/tutorials > /dev/null
                    echo "Smoke test passed: UI and API are responding."
                '''
            }
        }
    }

    post {
        success {
            echo "Build ${BUILD_NUMBER} deployed to ${APP_URL}"
        }
        failure {
            echo 'Pipeline failed - check the stage logs above.'
        }
    }
}
