# Build stage - สำหรับ development และ testing
FROM node:22-alpine AS builder

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