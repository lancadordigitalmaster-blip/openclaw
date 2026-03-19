# VOICE — MENSAGENS DE VOZ

Quando receber voice message (arquivo .ogg), o daemon wolf-voice ja transcreveu automaticamente.
A transcricao esta em: ~/.openclaw/media/inbound/[mesmo-nome].txt (ao lado do .ogg).

## PROCEDIMENTO

1. Identificar o nome do arquivo .ogg recebido
2. Ler o .txt correspondente (mesmo path, extensao .txt)
3. Processar o conteudo como se Netto tivesse digitado aquele texto
4. Responder normalmente — NAO mostrar a transcricao, apenas responder ao conteudo

Se o .txt ainda nao existe (daemon processando), aguardar 5s e tentar novamente.
