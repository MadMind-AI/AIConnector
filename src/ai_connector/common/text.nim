import strutils

# Тип для prompt
type Text* = seq[string]

# Создает новый text из строки
proc newText*(text: string): Text =
    return @[text]

# Создает новый text из нескольких строк
proc newText*(texts: varargs[string]): Text =
    result = @[]
    for text in texts:
        result.add(text)

# Преобразует текст в строку
proc toString*(text: Text): string =
    return text.join("\n")

# Добавляет строку в prompt с переносом строки
proc addLine*(text: var Text, line: string) =
    text.add(line)