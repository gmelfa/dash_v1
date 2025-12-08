"""
Query CLI - Ferramenta de linha de comando para gerenciar queries

Uso:
    python query_cli.py list                    # Lista todas as queries
    python query_cli.py list --category financeiro  # Filtra por categoria
    python query_cli.py search "termo"          # Busca queries
    python query_cli.py reload                  # Recarrega cache
    python query_cli.py stats                   # Mostra estatísticas
    python query_cli.py validate                # Valida sintaxe SQL (futuro)
"""

import argparse
import sys
from query_loader import QueryLoader
from tabulate import tabulate


def list_queries(args):
    """Lista queries"""
    loader = QueryLoader(queries_dir='queries')
    loader.load_all_queries()
    
    if args.category:
        queries = loader.list_queries(category=args.category)
        print(f"\n[Queries] Categoria '{args.category}':\n")
    else:
        queries = loader.list_queries()
        print(f"\n[Queries] Todas as queries:\n")
    
    if not queries:
        print("Nenhuma query encontrada.")
        return
    
    # Preparar dados para tabela
    table_data = []
    for q in queries:
        table_data.append([
            q['id'],
            q['name'][:40] + '...' if len(q['name']) > 40 else q['name'],
            q['category'],
            q['description'][:50] + '...' if len(q['description']) > 50 else q['description']
        ])
    
    # Exibir tabela
    headers = ['ID', 'Nome', 'Categoria', 'Descrição']
    print(tabulate(table_data, headers=headers, tablefmt='grid'))
    print(f"\nTotal: {len(queries)} queries")


def search_queries(args):
    """Busca queries por termo"""
    loader = QueryLoader(queries_dir='queries')
    loader.load_all_queries()
    
    results = loader.search_queries(args.term)
    
    print(f"\n[Busca] Resultados para '{args.term}':\n")
    
    if not results:
        print("Nenhuma query encontrada.")
        return
    
    # Preparar dados para tabela
    table_data = []
    for q in results:
        table_data.append([
            q['id'],
            q['name'][:40] + '...' if len(q['name']) > 40 else q['name'],
            q['category'],
            q['description'][:50] + '...' if len(q['description']) > 50 else q['description']
        ])
    
    # Exibir tabela
    headers = ['ID', 'Nome', 'Categoria', 'Descrição']
    print(tabulate(table_data, headers=headers, tablefmt='grid'))
    print(f"\nTotal: {len(results)} queries encontradas")


def reload_cache(args):
    """Recarrega o cache de queries"""
    loader = QueryLoader(queries_dir='queries')
    
    print("[Reload] Recarregando queries do diretorio...")
    count = loader.load_all_queries(force_reload=True)
    
    print(f"[OK] {count} queries recarregadas com sucesso!")
    
    # Mostrar estatísticas
    stats = loader.get_stats()
    print(f"\nTotal de queries: {stats['total_queries']}")
    print(f"Última atualização: {stats['last_update']}")


def show_stats(args):
    """Mostra estatísticas do sistema"""
    loader = QueryLoader(queries_dir='queries')
    loader.load_all_queries()
    
    stats = loader.get_stats()
    
    print("\n[Stats] Estatisticas do Sistema de Queries\n")
    print(f"Total de queries: {stats['total_queries']}")
    print(f"Diretorio: {stats['queries_directory']}")
    print(f"Ultima atualizacao: {stats['last_update']}")
    
    print("\n[Categorias] Queries por categoria:")
    for category, count in stats['queries_by_category'].items():
        print(f"  - {category}: {count} queries")


def validate_queries(args):
    """Valida sintaxe SQL de todas as queries"""
    print("[AVISO] Funcionalidade de validacao ainda nao implementada")
    print("Em breve: validacao automatica de sintaxe SQL")


def main():
    parser = argparse.ArgumentParser(
        description='Ferramenta CLI para gerenciar queries SQL',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  python query_cli.py list
  python query_cli.py list --category financeiro
  python query_cli.py search "resultado"
  python query_cli.py reload
  python query_cli.py stats
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Comandos disponíveis')
    
    # Comando: list
    list_parser = subparsers.add_parser('list', help='Lista queries')
    list_parser.add_argument('--category', '-c', help='Filtrar por categoria')
    list_parser.set_defaults(func=list_queries)
    
    # Comando: search
    search_parser = subparsers.add_parser('search', help='Busca queries')
    search_parser.add_argument('term', help='Termo de busca')
    search_parser.set_defaults(func=search_queries)
    
    # Comando: reload
    reload_parser = subparsers.add_parser('reload', help='Recarrega cache')
    reload_parser.set_defaults(func=reload_cache)
    
    # Comando: stats
    stats_parser = subparsers.add_parser('stats', help='Mostra estatísticas')
    stats_parser.set_defaults(func=show_stats)
    
    # Comando: validate
    validate_parser = subparsers.add_parser('validate', help='Valida sintaxe SQL')
    validate_parser.set_defaults(func=validate_queries)
    
    # Parse argumentos
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Executar comando
    try:
        args.func(args)
    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
