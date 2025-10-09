pipeline {
  
    // ใช้ any agent เพื่อหลีกเลี่ยงปัญหา Docker path mounting บน Windows
    agent any

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

        // Stage 2: Check and install Docker if needed
        stage('Setup Environment') {
            steps {
                script {
                    def isWindows = isUnix() ? false : true
                    
                    // Check if Docker is installed
                    def hasDocker = false
                    try {
                        if (isWindows) {
                            bat 'docker --version'
                        } else {
                            sh 'docker --version'
                        }
                        hasDocker = true
                        echo "Docker is already installed"
                    } catch (Exception e) {
                        echo "Docker not found, attempting to install..."
                        if (!isWindows) {
                            sh '''
                                sudo apt-get update
                                sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
                                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
                                sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
                                sudo apt-get update
                                sudo apt-get install -y docker-ce
                                sudo usermod -aG docker jenkins
                            '''
                        } else {
                            error "Please install Docker manually on Windows"
                        }
                    }
                }
            }
        }

        // Stage 3: Install dependencies and run tests
        stage('Install & Test') {
            steps {
                script {
                    def isWindows = isUnix() ? false : true
                    
                    echo "Running tests using Docker..."
                    if (isWindows) {
                        bat '''
                            docker run --rm ^
                            -v "%cd%":/workspace ^
                            -w /workspace ^
                            node:22-alpine sh -c "npm install && npm test"
                        '''
                    } else {
                        sh '''
                            docker run --rm \\
                            -v "$(pwd)":/workspace \\
                            -w /workspace \\
                            node:22-alpine sh -c "npm install && npm test"
                        '''
                    }
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
                    def isWindows = isUnix() ? false : true
                    echo "Cleaning up local Docker images/cache on agent..."
                    if (isWindows) {
                        bat """
                            docker image rm -f ${DOCKER_REPO}:${BUILD_NUMBER} || echo ignore
                            docker image rm -f ${DOCKER_REPO}:latest || echo ignore
                            docker image prune -af -f
                            docker builder prune -af -f
                        """
                    } else {
                        sh """
                            docker image rm -f ${DOCKER_REPO}:${BUILD_NUMBER} || true
                            docker image rm -f ${DOCKER_REPO}:latest || true
                            docker image prune -af -f
                            docker builder prune -af -f
                        """
                    }
                }
            }
        }

        // Stage 6: Deploy ไปยังเครื่อง local (รองรับทุก Platform)
        stage('Deploy Local') {
            steps {
                script {
                    def isWindows = isUnix() ? false : true
                    echo "Deploying container ${APP_NAME} from latest image..."
                    if (isWindows) {
                        bat """
                            docker pull ${DOCKER_REPO}:latest
                            docker stop ${APP_NAME} || echo ignore
                            docker rm ${APP_NAME} || echo ignore
                            docker run -d --name ${APP_NAME} -p 3000:3000 ${DOCKER_REPO}:latest
                            docker ps --filter name=${APP_NAME} --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\"
                        """
                    } else {
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

        // Stage 7: Deploy ไปยังเครื่อง remote server (ถ้ามี)
        // ต้องตั้งค่า SSH Key และอนุญาตให้ Jenkins เข้าถึง server
        // stage('Deploy to Server') {
        //     steps {
        //         script {
        //             def isWindows = isUnix() ? false : true
        //             echo "Deploying to remote server..."
        //             if (isWindows) {
        //                 bat """
        //                     ssh -o StrictHostKeyChecking=no user@your-server-ip \\
        //                     'docker pull ${DOCKER_REPO}:latest && \\
        //                     docker stop ${APP_NAME} || echo ignore && \\
        //                     docker rm ${APP_NAME} || echo ignore && \\
        //                     docker run -d --name ${APP_NAME} -p 3000:3000 ${DOCKER_REPO}:latest && \\
        //                     docker ps --filter name=${APP_NAME} --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
        //                 """
        //             } else {
        //                 sh """
        //                     ssh -o StrictHostKeyChecking=no user@your-server-ip \\
        //                     'docker pull ${DOCKER_REPO}:latest && \\
        //                     docker stop ${APP_NAME} || true && \\
        //                     docker rm ${APP_NAME} || true && \\
        //                     docker run -d --name ${APP_NAME} -p 3000:3000 ${DOCKER_REPO}:latest && \\
        //                     docker ps --filter name=${APP_NAME} --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
        //                 """
        //             }
        //         }
        //     }
        // }

    }
}