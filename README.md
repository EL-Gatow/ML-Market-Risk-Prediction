# ML-Market-Risk-Prediction

Sistem prediksi risiko pasar XAU/USD menggunakan Machine Learning yang terintegrasi dengan MetaTrader 5 (MT5) dan visualisasi real-time menggunakan KNN dan Random Forest

## Deskripsi Proyek

ML-Market-Risk-Prediction adalah sistem trading dashboard yang menghubungkan MetaTrader 5 (MT5) ke server Flask untuk memvisualisasikan data trading XAU/USD secara real-time dan memberikan prediksi risiko menggunakan model machine learning.

Sistem ini terdiri dari 3 komponen utama:
1. **Expert Advisor MT5** - Mengumpulkan data pasar dan indikator teknikal
2. **Server Flask** - Menerima data, melakukan prediksi, dan menyimpan data terbaru
3. **Dashboard Web** - Memvisualisasikan data dan hasil prediksi secara real-time

## Fitur Utama

- Visualisasi candlestick chart XAU/USD real-time
- Tampilan indikator teknikal (RSI, MA, MACD, ATR)
- Prediksi risiko pasar menggunakan model machine learning
- Sinyal ENTRY/HOLD berdasarkan hasil prediksi
- Tampilan data OHLC dan indikator teknikal
- Opsi untuk melihat semua data atau hanya data yang digunakan model

## Alur Kerja

1. **MT5 (DepTest.mq5)**:
   - Mengumpulkan data OHLC dan indikator teknikal (RSI, MA, MACD, ATR)
   - Mengirim data ke server Flask melalui HTTP POST
   - Menerima sinyal prediksi dan mengeksekusi order jika diperlukan

2. **Server Flask (server.py)**:
   - Menerima data dari MT5
   - Memproses data menggunakan model machine learning
   - Mengirim hasil prediksi kembali ke MT5
   - Menyimpan data terbaru untuk ditampilkan di dashboard

3. **Dashboard Web (index.html)**:
   - Mengambil data terbaru dari server Flask
   - Memvisualisasikan data dalam bentuk chart dan panel informasi
   - Menampilkan hasil prediksi risiko dan sinyal trading

## Cara Penggunaan

### Persiapan

1. **Instalasi Dependensi**:
   ```bash
   pip install flask pandas joblib scikit-learn
   ```

2. **Setup Model**:
   - Pastikan file model (`voting_model.pkl`), scaler (`scaler.pkl`), dan label encoder (`label_encoder.pkl`) tersedia di folder `model/`

### Menjalankan Server

1. **Jalankan Server Flask**:
   ```bash
   python server.py
   ```
   Server akan berjalan di `http://127.0.0.1:5000`

2. **Setup MT5**:
   - Buka MetaTrader 5
   - Aktifkan WebRequest:
     - Tools -> Options -> Expert Advisors
     - Centang "Allow WebRequests for listed URL"
     - Tambahkan `http://127.0.0.1:5000` ke daftar URL yang diizinkan
   - Compile dan load `DepTest.mq5` ke chart XAU/USD timeframe M15
   - Aktifkan AutoTrading jika ingin mengeksekusi order otomatis

3. **Akses Dashboard**:
   - Buka browser dan akses `http://127.0.0.1:5000`
   - Dashboard akan menampilkan data real-time setelah MT5 mengirimkan data

## Indikator yang Digunakan oleh Model

Model prediksi menggunakan 6 fitur utama:
- **Low** - Harga terendah
- **RSI_14** - Relative Strength Index periode 14
- **MA_20** - Moving Average periode 20
- **MACD_Main** - MACD Main Line
- **MACD_Signal** - MACD Signal Line
- **ATR_14** - Average True Range periode 14

## Parameter MT5

Beberapa parameter penting di Expert Advisor MT5:
- **DataSendInterval** - Interval pengiriman data (default: 900 detik / 15 menit)
- **RSI_Period** - Periode RSI (default: 14)
- **MA_Period** - Periode MA (default: 20)
- **ATR_Period** - Periode ATR (default: 14)
- **MACD_Fast** - Periode MACD Fast (default: 12)
- **MACD_Slow** - Periode MACD Slow (default: 26)
- **MACD_Signal** - Periode MACD Signal (default: 9)

## Struktur Proyek

```
ML-Market-Risk-Prediction/
  ├── model/
  │   ├── label_encoder.pkl
  │   ├── scaler.pkl
  │   └── voting_model.pkl
  ├── templates/
  │   └── index.html
  ├── DepTest.mq5
  ├── server.py
  └── README.md
```

## Troubleshooting

### Masalah Koneksi MT5
- Pastikan WebRequest diaktifkan di MT5
- Periksa apakah URL `http://127.0.0.1:5000` sudah ditambahkan ke daftar yang diizinkan
- Pastikan server Flask berjalan sebelum menjalankan EA di MT5

### Tidak Ada Data di Dashboard
- Periksa apakah EA di MT5 berjalan dengan benar
- Periksa log MT5 untuk melihat apakah ada error saat mengirim data
- Pastikan server Flask menerima request dari MT5

## Pengembangan Lanjutan

Beberapa ide untuk pengembangan lanjutan:
- Implementasi autentikasi untuk keamanan
- Penyimpanan data historis di database
- Penambahan indikator teknikal lainnya
- Optimasi model machine learning
- Implementasi strategi trading yang lebih kompleks

## Lisensi

Proyek ini dilisensikan di bawah [MIT License](https://opensource.org/licenses/MIT).

---
