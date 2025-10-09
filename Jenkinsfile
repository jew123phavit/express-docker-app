pipeline {
  
    // Use a Docker agent that has git and docker client installed.
    // This allows the pipeline to use docker commands by connecting to the host's Docker daemon.
    agent {
        docker {
            image 'docker:24.0-git'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    // กำหนด environment variables
    environment {
        // ใช้ค่าเป็น "credentialsId" ของ Jenkins โดยตรงสำหรับ docker.withRegistry
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-cred'
        DOCKER_REPO = "jew123phavit/express-docker-app"
        APP_NAME = "express-docker-app"
    }

    // กำหนด stages ของ Pipeline
    stages {

        // Stage 1: ดึงโค้ดล่าสุดจาก Git
        stage('Checkout') {
            steps {
                echo "Checking out code..."
                checkout scm
            }
        }

        // Stage 2: ติดตั้ง dependencies และรันเทสต์
        stage('Install & Test') {
            steps {
                script {
                    // The agent is a Linux container, so we directly use the 'sh' step.
                    echo "Using Docker to run tests..."
                    sh '''
                        docker run --rm \\
                        -v "$(pwd)":/workspace \\
                        -w /workspace \\
                        node:22-alpine sh -c "npm install && npm test"
                    '''
                }
            }
        }

        // Stage 3: สร้าง Docker Image สำหรับ production
        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image: ${DOCKER_REPO}:${BUILD_NUMBER}"
                    docker.build("${DOCKER_REPO}:${BUILD_NUMBER}", "--target production .")
                }
            }
        }

        // Stage 4: Push Image ไปยัง Docker Hub
        stage('Push Docker Image') {
            steps {
                script {
                    // ต้องส่งค่าเป็น credentialsId เท่านั้น ไม่ใช่ค่าที่ mask ของ credentials()
                    docker.withRegistry('https://index.docker.io/v1/', env.DOCKER_HUB_CREDENTIALS_ID) {
                        echo "Pushing image to Docker Hub..."
                        def image = docker.image("${DOCKER_REPO}:${BUILD_NUMBER}")
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }

        // Stage 5: เคลียร์ Docker images และ cache บน agent
        stage('Cleanup Docker') {
            steps {
                script {
                    echo "Cleaning up local Docker images/cache on agent..."
                    sh """
                        docker image rm -f ${DOCKER_REPO}:${BUILD_NUMBER} || true
                        docker image rm -f ${DOCKER_REPO}:latest || true
                        docker image prune -af -f
                        docker builder prune -af -f
                    """
                }
            }
        }

        // Stage 6: Deploy ไปยังเครื่อง local
        stage('Deploy Local') {
            steps {
                script {
                    echo "Deploying container ${APP_NAME} from latest image..."
                    sh """
                        docker pull ${DOCKER_REPO}:latest
                        docker stop ${APP_NAME} || true
                        docker rm ${APP_NAME} || true
                        docker run -d --name ${APP_NAME} -p 3000:3000 ${DOCKER_REPO}:latest
                        docker ps --filter name=${APP_NAME} --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
                    """
                }
            }
        }
    }
}