pipeline {
    // ใช้ agent any เพราะ build จะทำงานบน Jenkins controller (Linux container) อยู่แล้ว
    agent any

    // กัน “เช็คเอาต์ซ้ำซ้อน”
    // ถ้า job เป็นแบบ Pipeline from SCM / Multibranch แนะนำเพิ่ม options { skipDefaultCheckout(true) }
    // เพื่อปิดการ checkout อัตโนมัติก่อนเข้า stages (เพราะเรามี checkout scm อยู่แล้ว)
    options { 
        skipDefaultCheckout(true)   // ถ้าเป็น Pipeline from SCM/Multi-branch
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
        // ใช้ checkout scm หากใช้ Pipeline from SCM
        // หรือใช้ git url: 'https://github.com/your-username/your-repo.git'
        stage('Checkout') {
            steps {
                echo "Checking out code..."
                checkout scm
                // หรือใช้แบบกำหนดเอง หากไม่ใช้ Pipeline from SCM:
                // git url: 'https://github.com/your-username/your-repo.git'
            }
        }

        // Stage 2: ติดตั้ง dependencies และ Run test
        // ใช้ Node.js plugin (ต้องติดตั้ง NodeJS plugin ก่อน) ใน Jenkins หรือ Node.js ใน Docker 
        // ถ้ามี package-lock.json ให้ใช้ npm ci แทน npm install จะเร็วและล็อกเวอร์ชันชัดเจนกว่า
        stage('Install & Test') {
            steps {
                sh '''
                    if [ -f package-lock.json ]; then npm ci; else npm install; fi
                    npm test
                '''
            }
        }

        // Stage 3: สร้าง Docker Image
        // ใช้ Docker ที่ติดตั้งบน Jenkins agent (ต้องติดตั้ง Docker plugin ก่อน) ใน Jenkins หรือ Docker ใน Docker
        stage('Build Docker Image') {
            steps {
                sh """
                    echo "Building Docker image: ${DOCKER_REPO}:${BUILD_NUMBER}"
                    docker build --target production -t ${DOCKER_REPO}:${BUILD_NUMBER} -t ${DOCKER_REPO}:latest .
                """
            }
        }

        // Stage 4: Push Image ไปยัง Docker Hub
        // ใช้ Docker Hub credentials ที่ตั้งค่าไว้ใน Jenkins
        // DOCKER_USER และ DOCKER_PASS กำหนดไว้ที่ไหน?
        // ใน Jenkins Credentials (Username with password) โดยใช้ ID ที่กำหนดใน DOCKER_HUB_CREDENTIALS_ID ข้างบน
        // ตัวแปร DOCKER_USER และ DOCKER_PASS ไม่ได้ถูกกำหนดไว้ที่ไหนล่วงหน้าครับ แต่มันถูก "สร้างขึ้นมาชั่วคราว" โดยฟังก์ชัน withCredentials เอง
        // เมื่อเจอแล้ว มันจะนำค่า username และ password จาก Credential นั้นออกมา
        // ปลอดภัยหรือไม่? Password จะแสดงใน Log หรือเปล่า?
        // ปลอดภัยมาก และ Password จะไม่แสดงใน Log 
        // Jenkins ฉลาดพอที่จะรู้ว่าค่าที่มาจาก withCredentials เป็นข้อมูลลับ (Secret) ต่อให้คุณใช้คำสั่ง echo "${DOCKER_PASS}" Jenkins ก็จะ ไม่แสดงค่า Password จริงๆ ใน Console Log แต่จะแสดงเป็น ******** แทนโดยอัตโนมัติ
        // การทำงานของ Pipe | และ --password-stdin
        // echo "\${DOCKER_PASS}": คำสั่งนี้จะส่งค่า Password จริงๆ ออกไป
        // | (Pipe): แต่แทนที่จะส่งไปที่หน้าจอ Log, เครื่องหมาย pipe จะ ส่งต่อ (redirect) ผลลัพธ์ของ echo ไปเป็น Input (stdin) ของคำสั่งถัดไปทันที
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

        // Stage 5: เคลียร์ Docker images บน agent
        // เพื่อประหยัดพื้นที่บน Jenkins agent หลังจาก push image ขึ้น Docker Hub แล้ว
        // ไม่จำเป็นต้องเก็บ image ไว้บน agent อีกต่อไป
        // หลักการทำงานคือ ลบ image ที่สร้างขึ้น (ทั้งแบบมี tag build number และ latest)
        // และลบ cache ที่ไม่จำเป็นออกไป
        stage('Cleanup Docker') {
            steps {
                sh """
                    echo "Cleaning up local Docker images/cache on agent..."
                    docker image rm -f ${DOCKER_REPO}:${BUILD_NUMBER} || true
                    docker image rm -f ${DOCKER_REPO}:latest || true
                    docker image prune -af || true
                    docker builder prune -af || true
                """
            }
        }

        // Stage 6: Deploy ไปยังเครื่อง local
        // ดึง image ล่าสุดจาก Docker Hub มาใช้งาน
        // หยุดและลบ container เก่าที่ชื่อ ${APP_NAME} (ถ้ามี)
        // สร้างและรัน container ใหม่จาก image ล่าสุด
        stage('Deploy Local') {
            steps {
                sh """
                    echo "Deploying container ${APP_NAME} from latest image..."
                    docker pull ${DOCKER_REPO}:latest
                    docker stop ${APP_NAME} || true
                    docker rm ${APP_NAME} || true
                    docker run -d --name ${APP_NAME} -p 3000:3000 ${DOCKER_REPO}:latest
                    docker ps --filter name=${APP_NAME} --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}"
                """
            }
        }
    }

    // กำหนด post actions
    // เช่น การแจ้งเตือนเมื่อ pipeline เสร็จสิ้น
    // สามารถเพิ่มการแจ้งเตือนผ่าน email, Slack, หรืออื่นๆ ได้ตามต้องการ
    post {
        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}"
        }
        success {
            echo "Pipeline succeeded!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }

}
stage('Deploy Local') {
    steps {
        ...
    }
    // ส่งข้อมูลไปยัง n8n webhook เมื่อ deploy สำเร็จ
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
                    } catch (err) {
                        echo "httpRequest failed or not available: ${err}. Falling back to Java URLConnection..."
                        try {
                            def conn = new java.net.URL(N8N_WEBHOOK_URL).openConnection()
                            conn.setRequestMethod('POST')
                            conn.setDoOutput(true)
                            conn.setRequestProperty('Content-Type', 'application/json')
                            conn.getOutputStream().withWriter('UTF-8') { it << body }
                            int rc = conn.getResponseCode()
                            echo "n8n webhook (success) via URLConnection, response code: ${rc}"
                        } catch (e2) {
                            echo "Failed to notify n8n (success): ${e2}"
                        }
                    }
                }
            }
        }
    }
}

 post {
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