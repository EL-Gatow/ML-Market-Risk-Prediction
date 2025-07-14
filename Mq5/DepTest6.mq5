#property copyright "2025"
#property link      "https://www.mql5.com"
#property version   "1.00"
// PENTING: Untuk mengaktifkan WebRequest, buka Tools -> Options -> Expert Advisors
// dan tambahkan URL: http://127.0.0.1:5000 ke daftar URL yang diizinkan

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo position;

// Variabel untuk informasi pengiriman data
string lastResponse = "";
int lastErrorCode = 0;
string lastJsonSent = "";
bool webRequestEnabled = false;

input string FlaskURL = "http://127.0.0.1:5000/predict"; // URL server Flask
input int MagicNumber = 112233;
input double RiskPercent = 0.1;
input double MinLotSize = 0.01;
input int MaxPositions = 10;
input int TrailingStartPips = 15;
input int TrailingStopPips = 10;
input int RSI_Period = 14;
input int MA_Period = 20;
input int ATR_Period = 14;
input int MACD_Fast = 12;
input int MACD_Slow = 26;
input int MACD_Signal = 9;
input int DataSendInterval = 900; // Interval pengiriman data dalam detik (default 15 menit)

int rsiHandle, maHandle, atrHandle, macdHandle;
datetime lastDataSent = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   // Cek apakah WebRequest diaktifkan
   webRequestEnabled = CheckWebRequest();
   if(!webRequestEnabled)
   {
      Print("[ERROR] WebRequest tidak diaktifkan. Buka Tools -> Options -> Expert Advisors dan tambahkan URL: http://127.0.0.1:5000");
   }
   
   trade.SetExpertMagicNumber(MagicNumber);
   rsiHandle = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   maHandle = iMA(_Symbol, PERIOD_M15, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M15, ATR_Period);
   macdHandle = iMACD(_Symbol, PERIOD_M15, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);

   if(rsiHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE)
   {
      Print("Error: Gagal membuat handle indikator");
      return INIT_FAILED;
   }

   if(!SymbolSelect(_Symbol, true))
   {
      Print("Error: Simbol ", _Symbol, " tidak ditemukan di Market Watch");
      return INIT_FAILED;
   }

   if(Bars(_Symbol, PERIOD_M15) < MathMax(RSI_Period, MathMax(MA_Period, MathMax(ATR_Period, MACD_Slow))))
   {
      Print("Error: Data historis M15 tidak cukup");
      return INIT_FAILED;
   }
   
   // Aktifkan timer untuk pengiriman data berkala
   EventSetTimer(60); // Cek setiap 60 detik
   
   Print("EA berhasil diinisialisasi untuk simbol ", _Symbol, ", timeframe M15");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// Fungsi untuk mengecek apakah WebRequest diaktifkan
bool CheckWebRequest()
{
   string headers = "Content-Type: application/json\r\n";
   string response = "";
   uchar result[];
   uchar data[];
   int ret = WebRequest("GET", "http://127.0.0.1:5000", headers, 500, data, result, response);
   int errorCode = GetLastError();
   
   if(errorCode == 4060) // Tidak ada izin untuk WebRequest
   {
      Print("[ERROR] WebRequest tidak diizinkan. Buka Tools -> Options -> Expert Advisors dan tambahkan URL: http://127.0.0.1:5000");
      return false;
   }
   
   // Error 4014 berarti URL "tidak ada", tapi WebRequest diaktifkan
   if(errorCode == 4014)
      return true;
      
   return (errorCode == 0);
}

//+------------------------------------------------------------------+
double SafeDouble(double val)
{
   if(val == val && val != 0) return val; // Bukan NaN dan bukan 0
   return 0;
}

//+------------------------------------------------------------------+
string BuildJSON()
{
   double rsi[1], ma[1], atr[1], macdMain[1], macdSignal[1];
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) != 1 ||
      CopyBuffer(maHandle, 0, 0, 1, ma) != 1 ||
      CopyBuffer(atrHandle, 0, 0, 1, atr) != 1 ||
      CopyBuffer(macdHandle, 0, 0, 1, macdMain) != 1 ||
      CopyBuffer(macdHandle, 1, 0, 1, macdSignal) != 1)
   {
      Print("Error: Gagal mengambil data indikator");
      return "";
   }
   // Ambil data OHLC untuk candlestick
   double lowPrice = iLow(_Symbol, PERIOD_M15, 0);
   double highPrice = iHigh(_Symbol, PERIOD_M15, 0);
   double openPrice = iOpen(_Symbol, PERIOD_M15, 0);
   double closePrice = iClose(_Symbol, PERIOD_M15, 0);
   
   if(lowPrice == 0 || highPrice == 0 || openPrice == 0 || closePrice == 0)
   {
      Print("Error: Gagal mengambil data OHLC");
      return "";
   }

   if(rsi[0] == 0 || ma[0] == 0 || atr[0] == 0 || macdMain[0] == 0 || macdSignal[0] == 0)
   {
      Print("Error: Salah satu indikator bernilai 0");
      return "";
   }

   Print("[DEBUG] Open:", openPrice, " High:", highPrice, " Low:", lowPrice, " Close:", closePrice, 
         " RSI:", rsi[0], " MA:", ma[0], " MACD_Main:", macdMain[0], " MACD_Signal:", macdSignal[0], " ATR:", atr[0]);
   
   string json = StringFormat(
      "{\"Open\":%.5f,\"High\":%.5f,\"Low\":%.5f,\"Close\":%.5f,\"RSI_14\":%.5f,\"MA_20\":%.5f,\"MACD_Main\":%.5f,\"MACD_Signal\":%.5f,\"ATR_14\":%.5f}",
      SafeDouble(openPrice), SafeDouble(highPrice), SafeDouble(lowPrice), SafeDouble(closePrice), 
      SafeDouble(rsi[0]), SafeDouble(ma[0]), SafeDouble(macdMain[0]), SafeDouble(macdSignal[0]), SafeDouble(atr[0])
   );
   
   Print("[DEBUG] JSON Sent:", json);
   return json;
}

//+------------------------------------------------------------------+
string HttpPost(string url, string data)
{
   if(!webRequestEnabled)
   {
      Print("[ERROR] Tidak dapat melakukan HttpPost: WebRequest tidak diaktifkan");
      return "";
   }
   
   uchar postData[];
   StringToCharArray(data, postData, 0, StringLen(data));
   uchar result[];
   string headers = "Content-Type: application/json\r\n";
   string response;
   int timeout = 5000;
   
   Print("[HTTP REQUEST] Mengirim ke URL: ", url);
   Print("[HTTP REQUEST] Data: ", data);
   
   int res = WebRequest("POST", url, headers, timeout, postData, result, response);
   lastErrorCode = GetLastError();
   
   if(res == -1)
   {
      Print("[HTTP ERROR] Code:", lastErrorCode);
      
      // Menampilkan pesan error yang lebih detail
      switch(lastErrorCode)
      {
         case 4060: Print("[HTTP ERROR] WebRequest tidak diizinkan untuk URL ini"); break;
         case 4014: Print("[HTTP ERROR] URL tidak ditemukan"); break;
         case 4018: Print("[HTTP ERROR] Koneksi timeout"); break;
         case 4019: Print("[HTTP ERROR] Error internal HTTP"); break;
         default: Print("[HTTP ERROR] Kesalahan tidak dikenal");
      }
      
      return "";
   }
   
   string resultStr = CharArrayToString(result);
   Print("[SERVER RESPONSE]: ", resultStr);
   lastResponse = resultStr;
   lastJsonSent = data;
   
   return resultStr;
}

//+------------------------------------------------------------------+
// Menghitung jumlah posisi yang dibuka oleh EA ini saja
int CountEAPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() == MagicNumber && position.Symbol() == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
void SendLatestDataToServer()
{
   string json = BuildJSON();
   if(json == "")
   {
      Print("[ERROR] Gagal membuat JSON untuk data terbaru");
      return;
   }
   
   // URL tetap, pastikan sama dengan yang berhasil diuji dengan curl
   string url = "http://127.0.0.1:5000/get_latest_data";
   
   Print("[DEBUG] Mengirim data ke endpoint get_latest_data: ", url);
   Print("[DEBUG] JSON data: ", json);
   
   string response = HttpPost(url, json);
   
   if(response == "")
   {
      Print("[ERROR] Gagal mengirim data terbaru ke server");
      Print("[ERROR] WebRequest error code: ", lastErrorCode);
      Print("[ERROR] Terakhir kali JSON dikirim: ", lastJsonSent);
      Print("[ERROR] Coba kembali dalam ", DataSendInterval, " detik");
   }
   else
   {
      Print("[INFO] Data terbaru berhasil dikirim ke server: ", response);
   }
      
   lastDataSent = TimeCurrent();
}

//+------------------------------------------------------------------+
bool ShouldEntry()
{
   string json = BuildJSON();
   if(json == "")
   {
      Print("[ERROR] Gagal membuat JSON");
      return false;
   }
   string response = HttpPost(FlaskURL, json);
   if(response == "")
   {
      Print("[ERROR] Gagal mendapatkan respons server");
      return false;
   }
   if(StringFind(response, "\"signal\":\"ENTRY\"") != -1)
   {
      Print("[ML ENTRY DETECTED]: ", response);
      return true;
   }
   Print("[NO ENTRY] Risk too high: ", response);
   return false;
}

//+------------------------------------------------------------------+
void ExecuteOrder()
{
   int eaPositions = CountEAPositions();
   if(eaPositions >= MaxPositions)
   {
      Print("[INFO] Batas maksimum posisi EA tercapai: ", eaPositions, "/", MaxPositions);
      return;
   }
   
   if(!ShouldEntry()) return;
   double lot = AccountInfoDouble(ACCOUNT_EQUITY) * (RiskPercent / 100) / 10;
   lot = NormalizeDouble(MathMax(lot, MinLotSize), 2);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[1], ma[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) != 1 || CopyBuffer(maHandle, 0, 0, 1, ma) != 1)
   {
      Print("Error: Gagal mengambil ATR atau MA untuk order");
      return;
   }
   double price = iClose(_Symbol, PERIOD_M15, 0);
   double sl = atr[0] * 2.5;
   double tp = atr[0] * 1.0;
   if(price > ma[0])
   {
      if(trade.Buy(lot, _Symbol, ask, NormalizeDouble(ask - sl, _Digits), NormalizeDouble(ask + tp, _Digits), "ML-Buy"))
         Print("Buy order dibuka");
      else
         Print("Error membuka buy order: ", GetLastError());
   }
   else
   {
      if(trade.Sell(lot, _Symbol, bid, NormalizeDouble(bid + sl, _Digits), NormalizeDouble(bid - tp, _Digits), "ML-Sell"))
         Print("Sell order dibuka");
      else
         Print("Error membuka sell order: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
void TrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() != MagicNumber || position.Symbol() != _Symbol) continue;
         double currentPrice = (position.Type() == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double openPrice = position.PriceOpen();
         double sl = position.StopLoss();
         double pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double dist = TrailingStopPips * pip;
         double trigger = TrailingStartPips * pip;
         if(position.Type() == POSITION_TYPE_BUY && currentPrice - openPrice > trigger)
         {
            double newSL = NormalizeDouble(currentPrice - dist, _Digits);
            if(newSL > sl) trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
         }
         else if(position.Type() == POSITION_TYPE_SELL && openPrice - currentPrice > trigger)
         {
            double newSL = NormalizeDouble(currentPrice + dist, _Digits);
            if(newSL < sl || sl == 0) trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTimer()
{
   datetime currentTime = TimeCurrent();
   
   // Kirim data berdasarkan interval yang ditentukan
   if(currentTime - lastDataSent >= DataSendInterval)
   {
      SendLatestDataToServer();
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   Print("[INFO] Tick baru diterima");
   ExecuteOrder();
   TrailingStop();
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(rsiHandle);
   IndicatorRelease(maHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(macdHandle);
   EventKillTimer();
   Print("EA dihentikan, alasan: ", reason);
}