# BAB I
# PENDAHULUAN

## 1.1 Latar Belakang

Teknologi container telah menjadi fondasi utama dalam pengembangan dan deployment aplikasi modern. Docker, sebagai salah satu platform container terpopuler, mencatat lebih dari 318 miliar image pulls pada tahun 2021 dengan pertumbuhan penggunaan mencapai 145% dibandingkan tahun sebelumnya (Docker, 2021). Adopsi yang masif ini sejalan dengan proyeksi pasar container global yang diperkirakan mencapai USD 31,5 miliar pada tahun 2030 (Grand View Research, 2025).

Keamanan container bergantung pada mekanisme isolasi kernel Linux, yaitu namespace dan cgroups. Namespace membatasi ruang lingkup proses terhadap resource sistem seperti PID, jaringan, dan user ID, sedangkan cgroups membatasi konsumsi resource seperti CPU, memori, dan proses. Meskipun demikian, efektivitas isolasi tersebut bergantung pada konfigurasi runtime yang diterapkan.

Laporan keamanan menunjukkan bahwa 91% organisasi mengalami insiden keamanan container, dengan privilege escalation menjadi salah satu risiko utama (Sysdig, 2023). Docker dalam konfigurasi default masih menjalankan container dengan hak akses tinggi tanpa aktivasi penuh user namespace dan pembatasan resource, sehingga berpotensi menimbulkan privilege escalation dan resource exhaustion.

Standar keamanan seperti CIS Docker Benchmark menyediakan panduan konfigurasi aman, namun tingkat penerapannya di lingkungan produksi masih rendah dengan rata-rata kepatuhan sekitar 50–60% (CIS, 2023). Kondisi ini menunjukkan perlunya evaluasi praktis mengenai penerapan hardening berbasis namespace dan cgroups.

Penelitian ini menggunakan pendekatan eksperimental dengan membandingkan konfigurasi Docker default dan konfigurasi yang diperkuat, untuk mengevaluasi peningkatan isolasi keamanan serta dampaknya terhadap performa container. Hasil penelitian diharapkan menjadi acuan dalam penerapan security hardening container yang efektif dan efisien pada lingkungan produksi.

## 1.2 Identifikasi Masalah

Berdasarkan latar belakang yang telah diuraikan, dapat diidentifikasi beberapa permasalahan sebagai berikut:

1. Konfigurasi default Docker memiliki kelemahan pada penerapan prinsip least privilege dan defense-in-depth, dimana container berjalan sebagai root dengan capabilities berlebihan dan tanpa enforcement resource limits.

2. Belum adanya analisis sistematis mengenai efektivitas pendekatan berlapis (defense-in-depth) melalui konfigurasi namespace dan cgroup dalam memperkuat postur keamanan berdasarkan standar CIS Docker Benchmark.

3. Ketidakjelasan trade-off antara peningkatan keamanan melalui penerapan multiple security layers dengan overhead performa dalam implementasi security hardening untuk deployment production.

## 1.3 Rumusan Masalah

Berdasarkan identifikasi masalah tersebut, maka rumusan masalah penelitian ini adalah sebagai berikut:

1. Seberapa efektif pendekatan defense-in-depth melalui konfigurasi namespace dan cgroup dalam memperkuat isolasi keamanan container Docker?
2. Bagaimana peningkatan postur keamanan melalui implementasi multiple security layers berdasarkan standar CIS Docker Benchmark?
3. Berapa besar overhead performa dari implementasi defense-in-depth untuk kelayakan deployment production?

## 1.4 Batasan Penelitian

Untuk menjaga fokus penelitian dan memastikan hasil yang mendalam serta terukur, penelitian ini dibatasi pada hal-hal berikut:

1. Penelitian menggunakan Docker Engine v28.x pada Ubuntu 24.04 LTS dengan Linux kernel 6.x, namespace (8 jenis), dan cgroup v2 sebagai resource controller.

2. Lingkup keamanan terbatas pada runtime security (isolasi container saat berjalan), tidak mencakup image scanning, supply chain security, dan orchestration-level security. Fokus pada kontrol CIS Docker Benchmark Section 5 (Container Runtime).

3. Pengujian dilakukan di lab environment terkontrol dengan hardware Apple M2 (8 cores, 4GB RAM). Validasi keamanan meliputi analisis user privilege, capabilities audit, security options, dan simulasi resource abuse.

4. Aplikasi test menggunakan Node.js Express sebagai proof of concept. Aplikasi bersifat stateless dan tidak mewakili kompleksitas production seperti microservices atau database.

5. Metrik performa fokus pada CPU overhead, memory overhead, startup time, dan HTTP latency. Penelitian tidak mengukur disk I/O, network bandwidth, dan long-term resource consumption.

## 1.5 Tujuan Penelitian

Tujuan umum penelitian ini adalah menganalisis dan mengimplementasikan konfigurasi namespace dan cgroup untuk penguatan isolasi keamanan container Docker melalui pendekatan defense-in-depth.

**Tujuan Khusus:**

1. Menganalisis efektivitas pendekatan berlapis (defense-in-depth) melalui konfigurasi namespace, cgroup, dan security options dalam memperkuat isolasi keamanan container.
2. Mengukur peningkatan postur keamanan melalui implementasi multiple security layers berdasarkan standar CIS Docker Benchmark.
3. Mengukur overhead performa dari implementasi defense-in-depth untuk menentukan kelayakan deployment production.

## 1.6 Manfaat Penelitian

**Manfaat Akademis:**

1. Memberikan metodologi sistematis untuk penguatan keamanan container sebagai referensi penelitian selanjutnya.
2. Menghasilkan kerangka kerja pengujian yang dapat direproduksi untuk penelitian keamanan container lainnya.

**Manfaat Praktis:**

1. Memberikan panduan implementasi defense-in-depth untuk sysadmin dan DevOps engineers dalam mengamankan Docker deployment.
2. Membantu organisasi mencapai kepatuhan CIS Docker Benchmark melalui penerapan multiple security layers.
3. Menyediakan data empiris mengenai trade-off keamanan dan performa untuk mendukung keputusan deployment production.

## 1.7 Metodologi Penelitian

Penelitian ini menggunakan pendekatan eksperimental dengan membandingkan dua konfigurasi: baseline (Docker default) dan hardened (dengan user namespace remapping dan cgroup v2 enforcement). Pengumpulan data dilakukan melalui studi literatur, eksperimen laboratorium, dan analisis komparatif menggunakan tools standar industri: docker-bench-security, stress-ng, sysbench, dan Apache Bench. Metrik evaluasi meliputi aspek keamanan (CIS compliance, capabilities reduction), isolasi (namespace completeness, resource limits enforcement), dan performa (CPU overhead, memory overhead, startup time).

## 1.8 Sistematika Penulisan

Penulisan skripsi ini disusun dalam lima bab dengan struktur sebagai berikut:

**BAB I PENDAHULUAN**

Berisi latar belakang, identifikasi masalah, rumusan masalah, batasan penelitian, tujuan penelitian, manfaat penelitian, metodologi penelitian, dan sistematika penulisan.

**BAB II LANDASAN TEORI**

Menguraikan teori fundamental tentang container Linux, mekanisme namespace dan cgroup, CIS Docker Benchmark sebagai standar keamanan, serta penelitian terkait tentang container security.

**BAB III ANALISA DAN PERANCANGAN**

Menjelaskan analisis kebutuhan penelitian, analisis sistem berjalan dan usulan, perancangan pengujian, serta metodologi pengujian keamanan, isolasi, dan performa.

**BAB IV HASIL DAN PEMBAHASAN**

Menyajikan hasil penelitian mencakup lingkungan pengujian, efektivitas isolasi namespace dan cgroup, postur keamanan CIS, overhead performa, analisis trade-off, serta validasi dan limitasi penelitian.

**BAB V PENUTUP**

Berisi kesimpulan penelitian, rekomendasi implementasi, dan saran untuk penelitian selanjutnya.
