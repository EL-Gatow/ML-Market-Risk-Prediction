from flask import Flask, request, jsonify, render_template
import pandas as pd
import joblib
import os
import time

app = Flask(__name__)

# Direktori model
MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
try:
    model = joblib.load(os.path.join(MODEL_DIR, "voting_model.pkl"))
    scaler = joblib.load(os.path.join(MODEL_DIR, "scaler.pkl"))
except Exception as e:
    print(f"[ERROR] Gagal memuat model atau scaler: {str(e)}")
    exit(1)

# Fitur yang diharapkan
FEATURES = ["Low", "RSI_14", "MA_20", "MACD_Main", "MACD_Signal", "ATR_14"]
# Fitur tambahan untuk ditampilkan di dashboard
DISPLAY_FEATURES = ["Open", "High", "Low", "Close"] + FEATURES

# Simpan data terbaru dan hasil prediksi
latest_data = {feature: 0.0 for feature in DISPLAY_FEATURES}
latest_prediction = {"risk_level": 0, "signal": "HOLD"}
last_update_time = 0

@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')

@app.route('/get_latest_data', methods=['GET'])
def get_latest_data():
    global latest_data, latest_prediction, last_update_time
    
    try:
        # Kembalikan data yang sudah disimpan dari endpoint /predict
        response_data = latest_data.copy()
        response_data["timestamp"] = last_update_time
        # Tambahkan hasil prediksi juga
        response_data["risk_level"] = latest_prediction["risk_level"]
        response_data["signal"] = latest_prediction["signal"]
        
        print(f"[DEBUG] Mengembalikan data terbaru: {response_data}")
        return jsonify(response_data)
            
    except Exception as e:
        print(f"[ERROR] Kesalahan saat mengelola data terbaru: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route('/predict', methods=['POST'])
def predict():
    global latest_data, latest_prediction, last_update_time
    
    try:
        # Ambil data JSON
        data = request.get_json(force=True)
        print(f"[DEBUG] Data diterima: {data}")

        # Validasi fitur
        if not data:
            print("[ERROR] Tidak ada data JSON")
            return jsonify({"error": "No JSON data provided"}), 400

        # Periksa semua fitur OHLC dan indikator
        required_features = ["Open", "High", "Low", "Close"] + FEATURES
        missing = [f for f in required_features if f not in data]
        if missing:
            print(f"[ERROR] Fitur hilang: {missing}")
            return jsonify({"error": f"Missing features: {', '.join(missing)}"}), 400

        # Validasi nilai numerik
        for feature in required_features:
            if not isinstance(data[feature], (int, float)):
                print(f"[ERROR] Fitur {feature} bukan numerik: {data[feature]}")
                return jsonify({"error": f"Feature {feature} must be numeric"}), 400
            if data[feature] is None:
                print(f"[ERROR] Fitur {feature} null")
                return jsonify({"error": f"Feature {feature} cannot be null"}), 400

        # Buat DataFrame untuk prediksi (hanya menggunakan fitur yang dibutuhkan model)
        df = pd.DataFrame([{
            "Low": data["Low"],
            "RSI_14": data["RSI_14"],
            "MA_20": data["MA_20"],
            "MACD_Main": data["MACD_Main"],
            "MACD_Signal": data["MACD_Signal"],
            "ATR_14": data["ATR_14"]
        }])
        print(f"[DEBUG] DataFrame: {df.to_dict()}")

        # Skalakan data
        X_scaled = scaler.transform(df)
        print(f"[DEBUG] Data setelah scaling: {X_scaled}")

        # Prediksi
        pred = model.predict(X_scaled)[0]
        signal = "ENTRY" if pred == 1 else "HOLD"

        print(f"[PREDICTION] risk_level: {pred}, signal: {signal}")
        
        # Simpan data dan prediksi terbaru
        # Perbarui latest_data dengan semua fitur yang diterima
        for key in data:
            latest_data[key] = data[key]
        
        latest_prediction = {"risk_level": int(pred), "signal": signal}
        last_update_time = time.time()
        print(f"[INFO] Data dan prediksi tersimpan pada: {time.ctime(last_update_time)}")

        return jsonify({
            "risk_level": int(pred),
            "signal": signal
        })

    except Exception as e:
        print(f"[ERROR] Kesalahan server: {str(e)}")
        return jsonify({"error": f"Server error: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=True)