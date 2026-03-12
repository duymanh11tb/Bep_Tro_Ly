import requests

api_key = "AIzaSyCGb4dikSnCqDbKKtKAMkdrmaFMgSpf-uQ"
url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"

try:
    response = requests.get(url)
    if response.status_code == 200:
        models = response.json().get('models', [])
        print("Available models:")
        for model in models:
            print(f"- {model['name']}")
    else:
        print(f"Error {response.status_code}: {response.text}")
except Exception as e:
    print(f"Error: {e}")
