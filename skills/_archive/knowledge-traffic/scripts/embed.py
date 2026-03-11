#!/usr/bin/env python3
import json, time, sys
from pathlib import Path
import google.generativeai as genai
from dotenv import load_dotenv
import os

load_dotenv(Path.home() / '.openclaw/workspace/.env')
genai.configure(api_key=os.environ['GEMINI_API_KEY'])

MODEL = 'models/gemini-embedding-001'
BATCH, DELAY = 20, 0.5

def embed_batch(texts):
    return genai.embed_content(model=MODEL, content=texts, task_type='retrieval_document')['embedding']

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else 'chunks.json'
    out = sys.argv[2] if len(sys.argv) > 2 else src.replace('chunks','embedded')
    data = json.loads(Path(src).read_text())
    chunks = data['chunks']
    print(f"Vetorizando {len(chunks)} chunks de '{data['source']}'...")
    for i in range(0, len(chunks), BATCH):
        batch = chunks[i:i+BATCH]
        embs = embed_batch([c['content'] for c in batch])
        for c, e in zip(batch, embs): c['embedding'] = e
        print(f"  [{i+len(batch)}/{len(chunks)}] vetorizados")
        if i + BATCH < len(chunks): time.sleep(DELAY)
    data['embedded'] = True
    Path(out).write_text(json.dumps(data, ensure_ascii=False))
    print(f"✅ Embeddings prontos → {out}")

if __name__ == '__main__':
    main()
