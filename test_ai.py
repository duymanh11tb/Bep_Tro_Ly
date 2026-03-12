import requests
import json

# QUAN TRỌNG: Bạn TOÀN BỘ dòng này bằng API Key thật lấy từ: 
# https://aistudio.google.com/app/apikey
api_key = "AIzaSyCGb4dikSnCqDbKKtKAMkdrmaFMgSpf-uQ" # Dán mã thật của bạn vào đây

url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}"
headers = {'Content-Type': 'application/json'}
data = {"contents": [{"parts":[{"text": "Xin chào"}]}]}

print(f"Đang thử kết nối với API Key: {api_key[:10]}...")

try:
    response = requests.post(url, headers=headers, data=json.dumps(data))
    if response.status_code == 200:
        print("✅ THÀNH CÔNG! AI đã phản hồi.")
        print(f"Nội dung: {response.json()['candidates'][0]['content']['parts'][0]['text']}")
    else:
        print(f"❌ LỖI {response.status_code}: {response.text}")
except Exception as e:
    print(f"Lỗi kết nối: {e}")
