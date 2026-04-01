#!/usr/bin/env python3
import json, sys
from pathlib import Path
from supabase import create_client
from dotenv import load_dotenv
import os

load_dotenv(Path.home() / '.openclaw/workspace/.env')
sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_KEY'])

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else 'embedded.json'
    data = json.loads(Path(src).read_text())
    source = data['source']
    chunks = [c for c in data['chunks'] if 'embedding' in c]
    print(f"Inserindo {len(chunks)} chunks de '{source}'...")
    ok, err = 0, 0
    for c in chunks:
        try:
            sb.table('knowledge_base').insert({
                'source': source, 'topic': c['topic'],
                'chunk_index': c['chunk_index'], 'content': c['content'],
                'embedding': c['embedding'],
                'metadata': {'char_count': c.get('char_count',0), 'skill':'knowledge-traffic'},
            }).execute()
            ok += 1
        except Exception as e:
            print(f"  ⚠️ chunk {c['chunk_index']}: {e}"); err += 1
    print(f"✅ {ok} inseridos, {err} erros — '{source}' disponível para Alfred e Rex")

if __name__ == '__main__':
    main()
