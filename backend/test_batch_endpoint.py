import requests
import json

# Simular uma requisição de batch export
url = "http://localhost:5000/api/export/pptx/batch"

# Dados - simular seleção de uma query
data = {
    "query_ids": ["resultado_10_2025"]
}

print("Testando endpoint batch export...")
print(f"URL: {url}")
print(f"Payload: {json.dumps(data, indent=2)}")
print("\nEnviando requisição...")

try:
    # Nota: Precisa estar autenticado para funcionar
    response = requests.post(url, json=data)
    print(f"\nStatus Code: {response.status_code}")
    print(f"Headers: {response.headers}")
    
    if response.status_code == 200:
        print("✓ Sucesso! PowerPoint gerado")
        print(f"Tamanho do arquivo: {len(response.content)} bytes")
    else:
        print(f"✗ Erro: {response.text}")
        
except Exception as e:
    print(f"\n✗ Exceção: {str(e)}")
    import traceback
    traceback.print_exc()
