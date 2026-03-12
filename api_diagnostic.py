import requests
import json

api_key = "[ENCRYPTION_KEY]"

tests = [
    ("v1", "gemini-1.5-flash"),
    ("v1", "gemini-1.5-flash-latest"),
    ("v1beta", "gemini-1.5-flash"),
    ("v1beta", "gemini-2.0-flash"),
    ("v1beta", "gemini-pro"),
    ("v1", "gemini-pro")
]

payload = {
    "contents": [{"parts":[{"text": "Xin chào, hãy trả lời ngắn gọn trong 1 câu."}]}]
}

print(f"Bắt đầu kiểm tra với API Key: {api_key[:10]}...")

for version, model in tests:
    url = f"https://generativelanguage.googleapis.com/{version}/models/{model}:generateContent?key={api_key}"
    print(f"\n--- Thử nghiệm: {version} | {model} ---")
    try:
        response = requests.post(url, json=payload, timeout=10)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            print("✅ THÀNH CÔNG!")
            print(f"Phản hồi: {response.json()['candidates'][0]['content']['parts'][0]['text']}")
        else:
            print(f"❌ THẤT BẠI: {response.text}")
    except Exception as e:
        print(f"⚠️ Lỗi kết nối: {e}")

print("\n--- Hoàn tất kiểm tra ---")
