pipeline {
    // ใช้ Docker agent ที่มี git และ docker client ติดตั้งอยู่
    agent {
        docker {
            image 'docker:24.0-git'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    // กำหนด environment variables
    environment {
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-cred'
        DOCKER_REPO               = "jew123phavit/express-docker-app-jenkins" //
        APP_NAME                  = "express-docker-app-jenkins" //
    }

    // กำหนด stages ของ Pipeline
    stages {

        // Stage 1: ดึงโค้ดล่าสุดจาก Git
        stage('Checkout') {
            steps {
                echo "Checking out code..."
                checkout scm //
            }
        }

        // Stage 2: ติดตั้ง dependencies และรันเทสต์
        stage('Install & Test') {
            steps {
                echo "Running tests inside a node container..."
                // รันคำสั่ง npm ภายใน container ของ node:22-alpine
                sh '''
                    docker run --rm \\
                    -v "$(pwd)":/app \\
                    -w /app \\
                    node:22-alpine sh -c "npm install && npm test"
                '''
            }
        }

        // Stage 3: สร้าง Docker Image
        stage('Build Docker Image') {
            steps {
                sh """
                    echo "Building Docker image: ${DOCKER_REPO}:${BUILD_NUMBER}"
                    docker build --target production -t ${DOCKER_REPO}:${BUILD_NUMBER} -t ${DOCKER_REPO}:latest .
                """ //
            }
        }

        // Stage 4: Push Image ไปยัง Docker Hub
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
                    """ //
                }
            }
        }

        // Stage 5: Deploy ไปยังเครื่อง local
        stage('Deploy Local') {
            steps {
                sh """
                    echo "Deploying container ${APP_NAME} from latest image..."
                    docker pull ${DOCKER_REPO}:latest
                    docker stop ${APP_NAME} || true
                    docker rm ${APP_NAME} || true
                    docker run -d --name ${APP_NAME} -p 3300:3000 ${DOCKER_REPO}:latest
                    docker ps --filter name=${APP_NAME} --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}"
                """ //
            }
        }
    }

    // ส่วน Post-build actions: จะรันหลังทุก stages ทำงานเสร็จ
    post {
        // ทำงานเสมอ ไม่ว่า pipeline จะสำเร็จหรือล้มเหลว
        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}" //
            // ทำการ Cleanup Docker images
            sh """
                echo "Cleaning up local Docker images/cache on agent..."
                docker image rm -f ${DOCKER_REPO}:${BUILD_NUMBER} || true
                docker image rm -f ${DOCKER_REPO}:latest || true
                docker image prune -af || true
                docker builder prune -af || true
            """ //
        }
        // ทำงานเมื่อ pipeline สำเร็จเท่านั้น
        success {
            echo "Pipeline succeeded!" //
            // ส่ง Webhook ไปยัง n8n เมื่อสำเร็จ
            script {
                withCredentials([string(credentialsId: 'n8n-webhook', variable: 'N8N_WEBHOOK_URL')]) {
                    def payload = [
                        project  : env.JOB_NAME,
                        stage    : 'Deploy Local',
                        status   : 'success',
                        build    : env.BUILD_NUMBER,
                        image    : "${env.DOCKER_REPO}:latest",
                        container: env.APP_NAME,
                        url      : 'http://localhost:3300/', // แก้ port ให้ตรงกับที่ deploy
                        timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX")
                    ] //
                    def body = groovy.json.JsonOutput.toJson(payload)
                    try {
                        httpRequest(
                            acceptType: 'APPLICATION_JSON', contentType: 'APPLICATION_JSON',
                            httpMode: 'POST', requestBody: body,
                            url: N8N_WEBHOOK_URL, validResponseCodes: '100:599'
                        ) //
                        echo 'n8n webhook (success) sent via httpRequest.' //
                    } catch (err) {
                        echo "Failed to notify n8n (success): ${err}" //
                    }
                }
            }
        }
        // ทำงานเมื่อ pipeline ล้มเหลวเท่านั้น
        failure {
            echo "Pipeline failed!" //
            // ส่ง Webhook ไปยัง n8n เมื่อล้มเหลว
            script {
                withCredentials([string(credentialsId: 'n8n-webhook', variable: 'N8N_WEBHOOK_URL')]) {
                    def payload = [
                        project  : env.JOB_NAME,
                        stage    : 'Pipeline',
                        status   : 'failed',
                        build    : env.BUILD_NUMBER,
                        image    : 'n/a',
                        container: 'n/a',
                        url      : 'n/a',
                        timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX")
                    ] //
                    def body = groovy.json.JsonOutput.toJson(payload)
                    try {
                        httpRequest(
                            acceptType: 'APPLICATION_JSON', contentType: 'APPLICATION_JSON',
                            httpMode: 'POST', requestBody: body,
                            url: N8N_WEBHOOK_URL, validResponseCodes: '100:599'
                        ) //
                        echo 'n8n webhook (failure) sent via httpRequest.' //
                    } catch (err) {
                        echo "Failed to notify n8n (failure): ${err}" //
                    }
                }
            }
        }
    }
}