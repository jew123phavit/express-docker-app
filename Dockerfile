# ใช้ Official Jenkins Image เป็น Base
FROM jenkins/jenkins:jdk21

# สลับไปใช้ User root ชั่วคราวเพื่อติดตั้งโปรแกรม
USER root

# ติดตั้ง Docker CLI (วิธีที่ง่ายและครอบคลุมกว่า)
RUN apt-get update && apt-get install -y docker.io

# เพิ่ม user 'jenkins' เข้าไปใน group 'docker' ภายใน container
# เพื่อให้มีสิทธิ์เรียกใช้ docker.sock
RUN usermod -aG docker jenkins

# สลับกลับไปใช้ User jenkins ตามเดิม
USER jenkins

# กำหนด Working Directory ภายใน Container
WORKDIR /app

# Copy ไฟล์ package.json และ package-lock.json เข้าไปก่อน
# เพื่อใช้ประโยชน์จาก Docker cache layer ทำให้ไม่ต้อง install dependencies ใหม่ทุกครั้งที่แก้โค้ด
COPY package*.json ./

# ติดตั้ง Dependencies (รวม dev dependencies สำหรับ testing)
RUN npm install

# Copy โค้ดทั้งหมดในโปรเจกต์เข้าไปใน container
COPY . .

# Compile TypeScript เป็น JavaScript
RUN npm run build

# Production stage - สำหรับ production deployment
FROM node:22-alpine AS production

# กำหนด Working Directory ภายใน Container
WORKDIR /app

# Copy package files
COPY package*.json ./

# ติดตั้งเฉพาะ production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy โค้ดที่ compiled แล้วจาก builder stage
COPY --from=builder /app/dist ./dist
# COPY --from=builder /app/src ./src

# กำหนด Port ที่ Container จะทำงาน
EXPOSE 3000

# คำสั่งสำหรับรัน Express Application (ใช้ compiled JavaScript)
CMD ["npm", "start"]