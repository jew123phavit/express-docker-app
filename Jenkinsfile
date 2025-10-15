pipeline {
    // ใช้ agent ที่มีทั้ง git และ docker client
    // agent any จะทำให้ Jenkins เลือก agent ที่ว่าง, แต่เราต้องการ agent ที่มี docker
    // ดังนั้นการระบุ agent ด้านล่างจึงดีกว่า
    agent any

    // (แนะนำ) ถ้า job เป็นแบบ Pipeline from SCM ให้เปิดใช้ option นี้
    options { 
        skipDefaultCheckout(true)
    }

    // กำหนด environment variables
    environment {
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-cred'
        DOCKER_REPO               = "jew123phavit/express-docker-app-jenkins"
        APP_NAME                  = "express-docker-app-jenkins"
    }

    // กำหนด stages ของ Pipeline
    stages {

        // Stage 1: ดึงโค้ดล่าสุดจาก Git
        stage('Checkout') {
            steps {
                echo "Checking out code..."
                cleanWs() // ล้าง workspace ให้สะอาดก่อน
                checkout scm
            }
        }

        // Stage 2: ติดตั้ง dependencies และ Run test (ตามที่คุณต้องการ)
        stage('Install & Test') {
            steps {
                script {
                    docker.image('node:22-alpine').inside {
                        sh '''
                            if [ -f package-lock.json ]; then npm ci; else npm install; fi
                            npm test
                        '''
                    }
                }
            }
        }

        // Stage 3: สร้าง Docker Image
        stage('Build Docker Image') {
            steps {
                sh """
                    echo "Building Docker image: ${DOCKER_REPO}:${BUILD_NUMBER}"
                    docker build --target production -t ${DOCKER_REPO}:${BUILD_NUMBER} -t ${DOCKER_REPO}:latest .
                """
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
                    """
                }
            }
        }

        // Stage 5: Deploy ไปยังเครื่อง local
        stage('Deploy Local') {
            steps {
                script {
                    docker.withTool('docker') {
                        sh """
                            echo "Stopping and removing old container ${APP_NAME}..."
                            docker stop ${APP_NAME} || true
                            docker rm ${APP_NAME} || true
                            
                            echo "Running new container ${APP_NAME} with image ${DOCKER_REPO}:latest"
                            docker run -d \
                                --name ${APP_NAME} \
                                -p 3000:3000 \
                                ${DOCKER_REPO}:latest
                        """
            }
            // ส่งข้อมูลไปยัง n8n webhook 
            // เมื่อ deploy สำเร็จ
            // ใช้ Jenkins HTTP Request Plugin (ต้องติดตั้งก่อน)
            // หรือใช้ Java URLConnection แทน (fallback) ถ้า httpRequest ไม่ได้ติดตั้ง
            // n8n-webhook คือ Jenkins Secret Text Credential ที่เก็บ URL ของ n8n webhook
            // ต้องสร้าง Credential นี้ใน Jenkins ก่อน ใช้งาน
            // โดยใช้ ID ว่า n8n-webhook

            post {
                success {
                    script {
                        withCredentials([string(credentialsId: 'n8n-webhook', variable: 'N8N_WEBHOOK_URL')]) {
                            def payload = [
                                project  : env.JOB_NAME,
                                stage    : 'Deploy Local',
                                status   : 'success',
                                build    : env.BUILD_NUMBER,
                                image    : "${env.DOCKER_REPO}:latest",
                                container: env.APP_NAME,
                                url      : 'http://localhost:3000/',
                                timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX")
                            ]
                            def body = groovy.json.JsonOutput.toJson(payload)
     
                            try {
                                httpRequest acceptType: 'APPLICATION_JSON',
                                            contentType: 'APPLICATION_JSON',
                                            httpMode: 'POST',
                                            requestBody: body,
                                            url: N8N_WEBHOOK_URL,
                                            validResponseCodes: '100:599'
                                echo 'n8n webhook (success) sent via httpRequest.'
                            } 
                            catch (err) 
                            {
                                echo "httpRequest failed or not available: ${err}. Falling back to Java URLConnection..."
                      
                                try {
                                    def conn = new java.net.URL(N8N_WEBHOOK_URL).openConnection()
                                    conn.setRequestMethod('POST')
                                    conn.setDoOutput(true)
         
                                    conn.setRequestProperty('Content-Type', 'application/json')
                                    conn.getOutputStream().withWriter('UTF-8') { it << body }
                                    int rc = conn.getResponseCode()
                
                                    echo "n8n webhook (success) via URLConnection, response code: ${rc}"
                                } 
                                catch (e2) 
                                {
                                    echo "Failed to notify n8n (success): ${e2}"
                                }
                            }
                        }
                    }
                }
            }
        }
    } // <--- วงเล็บปีกกาปิดของบล็อก stages ถูกเพิ่มเข้ามาที่นี่
    
    post { // <--- Global post block
        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}"
        }
        success {
            echo "Pipeline succeeded!"
        }
        failure {
            // ส่งข้อมูลไปยัง n8n webhook เมื่อ pipeline ล้มเหลว
            // ใช้ Jenkins HTTP Request Plugin (ต้องติดตั้งก่อน)
            // หรือใช้ Java URLConnection แทน (fallback) ถ้า httpRequest ไม่ได้ติดตั้ง
            // n8n-webhook คือ Jenkins Secret Text Credential ที่เก็บ URL ของ n8
            // ต้องสร้าง Credential นี้ใน Jenkins ก่อน ใช้งาน
            // โดยใช้ ID ว่า n8n-webhook
       
            script {
                withCredentials([string(credentialsId: 'n8n-webhook', variable: 'N8N_WEBHOOK_URL')]) {
                    def payload = [
                        project  : env.JOB_NAME,
                        stage    : 'Pipeline',
                        status   : 'failed',
                        build    : env.BUILD_NUMBER,
                        image    : "${env.DOCKER_REPO}:latest",
                        container: env.APP_NAME,
                        
                        url      : 'http://localhost:3000/',
                        timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX")
                    ]
                    def body = groovy.json.JsonOutput.toJson(payload)
                    try {
                        
                        httpRequest acceptType: 'APPLICATION_JSON',
                                    contentType: 'APPLICATION_JSON',
                                    httpMode: 'POST',
                                    
                                    requestBody: body,
                                    url: N8N_WEBHOOK_URL,
                                    validResponseCodes: '100:599'
                        echo 'n8n webhook (failure) sent via httpRequest.'
                    } catch (err) {
                        echo "httpRequest failed or not available: ${err}. Falling back to Java URLConnection..."
                        try {
                            def conn = new java.net.URL(N8N_WEBHOOK_URL).openConnection()
                            
                            conn.setRequestMethod('POST')
                            conn.setDoOutput(true)
                            conn.setRequestProperty('Content-Type', 'application/json')
                            conn.getOutputStream().withWriter('UTF-8') { it << body }
                            
                            int rc = conn.getResponseCode()
                            echo "n8n webhook (failure) via URLConnection, response code: ${rc}"
                        } catch (e2) {
                            echo "Failed to notify n8n (failure): ${e2}"
                        }
                    }
                }
            }
        }
    }
}
