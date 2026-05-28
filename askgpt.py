from openai import OpenAI
import os
import sys

api_key = os.environ.get("OPENAI_API_KEY")

if not api_key:
    print("Erro: variável OPENAI_API_KEY não encontrada.")
    sys.exit(1)

client = OpenAI(api_key=api_key)

pergunta = " ".join(sys.argv[1:])

resposta = client.responses.create(
    model="gpt-5.5",
    input=pergunta
)

print(resposta.output_text)
