# Script cirúrgico para corrigir App.jsx (Versão Oficial - Correção Capa)
# Substitui tudo entre 'const exportMultipleQueriesPPT' e 'if (!user) {'

with open('src/App.jsx', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Ler nova função
with open('batch_export_function.js', 'r', encoding='utf-8') as f:
    new_func_lines = f.readlines()[2:]

start_idx = None
end_idx = None

for i, line in enumerate(lines):
    if 'const exportMultipleQueriesPPT = async' in line:
        start_idx = i
    
    if 'if (!user) {' in line and start_idx is not None and i > start_idx:
        end_idx = i
        break

if start_idx is not None and end_idx is not None:
    new_lines = lines[:start_idx] + new_func_lines + ['\n'] + lines[end_idx:]
    
    with open('src/App.jsx', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ App.jsx atualizado com correção do seletor da capa!")
else:
    print("❌ Erro ao encontrar marcadores no arquivo")
