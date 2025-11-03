# ============================================
# Dockerfile untuk Penelitian Keamanan Container
# ============================================
#
# Tujuan: Base image netral untuk perbandingan keamanan yang adil
# Pendekatan: Image yang sama, konfigurasi runtime yang berbeda
#
# Desain Penelitian:
# - BASELINE: Dijalankan dengan flag default (tanpa hardening)
# - HARDENED: Dijalankan dengan flag keamanan (full hardening)
#
# Hal ini memastikan perbandingan yang ADIL:
# ✓ Base image yang sama (node:22-alpine)
# ✓ Kode aplikasi yang sama
# ✓ Dependencies yang sama
# ✓ Hanya security options RUNTIME yang berbeda
# ============================================

# Base image: Node.js 22 dengan Alpine Linux (minimal size)
FROM node:22-alpine

# Install tools untuk testing dan validasi
# - util-linux: Untuk lsns command (inspeksi namespace)
# - stress-ng: Enforcement testing (PIDs, memory stress)
# - sysbench: Performance benchmarking (CPU, memory overhead)
RUN apk add --no-cache \
    util-linux \
    stress-ng \
    sysbench

# Set working directory di dalam container
WORKDIR /app

# Copy file package.json dan package-lock.json untuk dependency
COPY package*.json ./

# Install dependencies production only (lebih ringan, tanpa dev dependencies)
RUN npm ci --only=production

# Copy source code aplikasi ke dalam container
COPY . .

# Expose port aplikasi
EXPOSE 3000

# Command untuk menjalankan aplikasi saat container start
CMD ["node", "app.js"]
