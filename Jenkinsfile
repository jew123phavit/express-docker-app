pipeline {
  
    // ใช้ any agent เพื่อหลีกเลี่ยงปัญหา Docker path mounting บน Windows
    agent any

    // กำหนด environment variables
    environment {
        // ใช้ค่าเป็น "credentialsId" ของ Jenkins โดยตรงสำหรับ docker.withRegistry
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-cred'
        DOCKER_REPO = "iamsamitdev/express-docker-app"
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

        // Stage 2: ติดตั้ง dependencies และรันเทสต์ (รองรับทุก Platform)
        stage('Install & Test') {
            steps {
                script {
                    // ตรวจสอบว่ามี Node.js บน host หรือไม่
                    def hasNodeJS = false
                    def isWindows = isUnix() ? false : true
                    
                    try {
                        if (isWindows) {
                            bat 'node --version && npm --version'
                        } else {
                            sh 'node --version && npm --version'
                        }
                        hasNodeJS = true
                        echo "Using Node.js installed on ${isWindows ? 'Windows' : 'Unix'}"
                    } catch (Exception e) {
                        echo "Node.js not found on host, using Docker"
                        hasNodeJS = false
                    }
                    
                    if (hasNodeJS) {
                        // ใช้ Node.js บน host
                        if (isWindows) {
                            bat '''
                                npm install
                                npm test
                            '''
                        } else {
                            sh '''
                                npm install
                                npm test
                            '''
                        }
                    } else {
                        // ใช้ Docker run command (รองรับทุก platform)
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