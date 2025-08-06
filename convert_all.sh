#!/bin/bash

mkdir -p test/out

for INPUT_FILE in test/cfiles/*.c; do
  # Extrai o nome sem extensão e pasta
  FILE_NUM=$(basename "$INPUT_FILE" .c)
  OUTPUT_FILE="test/out/${FILE_NUM}.rob"

  # Redireciona saída temporária para um arquivo intermediário
  TEMP_FILE=$(mktemp)

  echo "Convertendo $INPUT_FILE..."

  ./c2rob "$INPUT_FILE" > "$TEMP_FILE"
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    echo "Sucesso: gerado $OUTPUT_FILE"
  else
    echo "Erro na conversão de $INPUT_FILE. Pulando..."
    rm "$TEMP_FILE"
  fi
done

echo "Conversão concluída."
