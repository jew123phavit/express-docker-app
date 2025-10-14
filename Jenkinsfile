pipeline {
    agent {
        docker {
            image 'docker:24.0-git'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    // --- ส่วนที่ต้องแก้ไข ---
    environment {
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-cred'
        // เปลี่ยน "iamsamitdev" เป็น "jew123phavit"
        DOCKER_REPO               = "jew123phavit/express-docker-app-jenkins"
        APP_NAME                  = "express-docker-app-jenkins"
    }
    // --------------------

    stages {
        stage('Checkout') {
            steps {
                echo "Cleaning workspace and checking out from SCM..."
                cleanWs()
                checkout scm
            }
        }

        stage('Install & Test') {
            steps {
                sh '''
                    docker run --rm \\
                    -v "${WORKSPACE}":/app \\
                    -w /app \\
                    node:22-alpine sh -c "npm install && npm test"
                '''
            }
        }

        // ... (stages ที่เหลือทั้งหมดเหมือนเดิม) ...
        stage('Build Docker Image') {
            steps {
                sh """
                    echo "Building Docker image: ${DOCKER_REPO}:${BUILD_NUMBER}"
                    docker build --target production -t ${DOCKER_REPO}:${BUILD_NUMBER} -t ${DOCKER_REPO}:latest .
                """
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CREDENTIALS_ID, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "Logging into Docker Hub..."
                        echo "\${DOCKER_PASS}" | docker login -u "\${DOCKER_USER}" --password-stdin
                        echo "Pushing image to Docker Hub..."
                        docker push ${DOCKER_REPO}:${BUILD_NUMBER}
                        docker push ${DOCKER_REPO}:latest
                        docker logout
                    """
                }
            }
        }

        stage('Deploy Local') {
            steps {
                sh """
                    echo "Deploying container ${APP_NAME} from latest image..."
                    docker pull ${DOCKER_REPO}:latest
                    docker stop ${APP_NAME} || true
                    docker rm ${APP_NAME} || true
                    docker run -d --name ${APP_NAME} -p 3300:3000 ${DOCKER_REPO}:latest
                    docker ps --filter name=${APP_NAME} --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}"
                """
            }
        }
    }

    // ... (ส่วน post เหมือนเดิม) ...
    post {
        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}"
            sh """
                echo "Cleaning up local Docker images/cache on agent..."
                docker image rm -f ${DOCKER_REPO}:${BUILD_NUMBER} || true
            """
        }
        success {
            echo "Pipeline Succeeded!"
            // ส่ง notification
        }
        failure {
            echo "Pipeline Failed!"
            // ส่ง notification
        }
    }
}
