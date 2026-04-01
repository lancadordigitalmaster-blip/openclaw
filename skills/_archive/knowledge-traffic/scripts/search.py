#!/usr/bin/env python3
import sys
from supabase import create_client
from dotenv import load_dotenv
import google.generativeai as genai
import os
from pathlib import Path

load_dotenv(Path.home() / '.openclaw/workspace/.env')
genai.configure(api_key=os.environ['GEMINI_API_KEY'])
sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_KEY'])

def search(query, top_k=5):
    emb = genai.embed_content(model='models/gemini-embedding-001', content=query, task_type='retrieval_query')['embedding']
    return sb.rpc('search_knowledge', {'query_embedding':emb,'match_threshold':0.65,'match_count':top_k,'filter_topic':None}).execute().data

def main():
    query = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else 'estratégia de tráfego pago'
    print(f"🔍 '{query}'\n")
    for r in search(query):
        print(f"[{r['similarity']:.2f}] [{r['topic']}] {r['source']}")
        print(r['content'][:300])
        print("---")

if __name__ == '__main__':
    main()
