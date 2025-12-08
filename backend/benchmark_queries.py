import time
import os
from dotenv import load_dotenv
from databricks import sql
from query_loader import QueryLoader

# Load environment variables
load_dotenv()

# Databricks Configuration
DATABRICKS_SERVER_HOSTNAME = os.getenv('DATABRICKS_SERVER_HOSTNAME')
DATABRICKS_HTTP_PATH = os.getenv('DATABRICKS_HTTP_PATH')
DATABRICKS_TOKEN = os.getenv('DATABRICKS_TOKEN')

def get_connection():
    return sql.connect(
        server_hostname=DATABRICKS_SERVER_HOSTNAME,
        http_path=DATABRICKS_HTTP_PATH,
        access_token=DATABRICKS_TOKEN
    )

import threading
import sys

def run_benchmark_logic():
    print("="*60)
    print("🚀 STARTING QUERY BENCHMARK")
    print("="*60)

    # Initialize QueryLoader
    loader = QueryLoader(queries_dir='queries', db_path=':memory:')
    loader.load_all_queries()
    queries = loader.list_queries()
    
    print(f"Found {len(queries)} queries to test.\n")

    results = []
    total_start = time.time()

    try:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                for i, query in enumerate(queries):
                    q_id = query['id']
                    q_name = query['name']
                    sql_content = query['sql_content']
                    
                    print(f"[{i+1}/{len(queries)}] Testing: {q_name} ({q_id})...", end='', flush=True)
                    
                    start_time = time.time()
                    try:
                        cursor.execute(sql_content)
                        # Fetch one to ensure execution is complete
                        cursor.fetchone()
                        duration = time.time() - start_time
                        print(f" ✅ {duration:.2f}s")
                        
                        results.append({
                            'id': q_id,
                            'name': q_name,
                            'duration': duration,
                            'status': 'OK'
                        })
                    except Exception as e:
                        duration = time.time() - start_time
                        print(f" ❌ FAILED ({duration:.2f}s)")
                        print(f"    Error: {str(e)[:100]}...")
                        results.append({
                            'id': q_id,
                            'name': q_name,
                            'duration': duration,
                            'status': 'ERROR',
                            'error': str(e)
                    })

        total_duration = time.time() - total_start
        
        print("\n" + "="*60)
        print("📊 BENCHMARK RESULTS")
        print("="*60)
        
        # Sort by duration (descending)
        results.sort(key=lambda x: x['duration'], reverse=True)
        
        print(f"{'QUERY ID':<30} | {'DURATION':<10} | {'STATUS':<10}")
        print("-" * 60)
        
        for r in results:
            print(f"{r['id']:<30} | {r['duration']:.2f}s     | {r['status']}")
            
        print("-" * 60)
        print(f"Total Time: {total_duration:.2f}s")
        print(f"Average Time: {total_duration/len(queries):.2f}s")
        print("="*60)

    except Exception as e:
        print(f"\n❌ Fatal Error during benchmark: {e}")

def benchmark():
    # Set global timeout (10 minutes)
    TIMEOUT_SECONDS = 600
    
    # Run benchmark in a separate thread
    t = threading.Thread(target=run_benchmark_logic)
    t.daemon = True # Allow main program to exit even if thread is stuck
    t.start()
    
    # Wait for thread to finish or timeout
    t.join(TIMEOUT_SECONDS)
    
    if t.is_alive():
        print(f"\n\n⏰ TIMEOUT REACHED ({TIMEOUT_SECONDS}s) - Stopping benchmark.")
        print("The script was interrupted because it exceeded the time limit.")
        sys.exit(1)

if __name__ == "__main__":
    benchmark()
