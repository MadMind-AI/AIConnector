import httpclient
import json
import options
import strformat
import sequtils

import ./common/text
import ./common/logger_func
# Константы по умолчанию для OpenAI API
const
  # Константа для температуры генерации
  DEFAULT_TEMPERATURE* = 0.7
  # Константа для максимального количества токенов
  DEFAULT_MAX_TOKENS* = 150
  # Константа для стриминга ответа
  DEFAULT_STREAM* = false
  # Константа для успешного HTTP статуса
  HTTP_STATUS_OK* = "200 OK"

# Структура опций для запроса завершения
type CompleteOptions* = object
    # Опция для структурированного ответа
    structuredResponse*: Option[JsonNode]
    # Опция для температуры генерации
    temperature*: Option[float]
    # Опция для максимального количества токенов
    max_tokens*: Option[int]
    # Опция для стриминга ответа
    stream*: Option[bool]

# Тип для работы с OpenAI API
type OpenAiApi* = object
    # Базовый URL API
    baseUrl: string
    # HTTP заголовки
    headers: HttpHeaders

# Доступ к API с моделями
type ApiWithModels* = object
    # Установленные модели
    models*: seq[string]
    # API
    api*: OpenAiApi

# Источники API
type ApiCollection* = object
    # API с моделями
    apiWithModels*: seq[ApiWithModels]    

# Создает новый API с моделями
proc newApiWithModels*(api: OpenAiApi, models: seq[string]): ApiWithModels =
    return ApiWithModels(models: models, api: api)

# Создает новый источник API
proc newApiCollection*(apiWithModels: varargs[ApiWithModels]): ApiCollection =
    return ApiCollection(apiWithModels: apiWithModels.toSeq())

# Получает API для разрешенных моделей
proc getApi*(self: ApiCollection, allowedModels: seq[string]): (OpenAiApi, string) =
    for model in allowedModels:
        for apiWithModel in self.apiWithModels:
            if apiWithModel.models.contains(model):
                return (apiWithModel.api, model)
    raise newException(ValueError, "Модель не найдена")

# Получает HTTP клиент
proc getClient(self: OpenAiApi): HttpClient =
    result = newHttpClient()
    result.headers = self.headers

# Получает ответ от OpenAI API
proc getCompletions(self: OpenAiApi, requestBody:string, logger: Option[LoggerFunc]): string =
    let client = self.getClient()
    let url = self.baseUrl & "/v1/chat/completions"
    let response = client.post(url, requestBody)    
    if response.status != HTTP_STATUS_OK:
        raise newException(ValueError, fmt"API error: {response.body}")

    if logger.isSome:
        let loggerFunc = logger.get()
        loggerFunc(fmt"ответ: {response.body}")

    let jsonResponse = parseJson(response.body)
    return jsonResponse["choices"][0]["message"]["content"].getStr()

# Получает список моделей
proc getModels*(self: OpenAiApi): seq[string] =
    let client = self.getClient()
    let response = client.get(fmt"{self.baseUrl}/v1/models")  
    if response.status != HTTP_STATUS_OK:
        raise newException(ValueError, fmt"API error: {response.body}")

    let jsonResponse = parseJson(response.body)
    let models = jsonResponse["data"].getElems()
    for model in models:
        result.add(model["id"].getStr())

# Завершает текст с помощью OpenAI API
proc complete*(
        self: OpenAiApi, 
        model: string,
        systemPrompt: Text, 
        userPrompt: Text,
        options: Option[CompleteOptions] = none(CompleteOptions),
        logger: Option[LoggerFunc] = none(LoggerFunc)
    ): string =

    var messages: seq[JsonNode] = @[]
    
    if logger.isSome:
        let loggerFunc = logger.get()
        loggerFunc(fmt"Системный prompt:")
        loggerFunc(systemPrompt.toString())
        loggerFunc(fmt"Пользовательский prompt:")
        loggerFunc(userPrompt.toString())
    
    if systemPrompt.len > 0:
        for prompt in systemPrompt:
            messages.add(%* {"role": "system", "content": prompt})
    
    if userPrompt.len > 0:        
        for prompt in userPrompt:
            messages.add(%* {"role": "user", "content": prompt})

    var requestBody = %* {
        "model": model,
        "messages": messages,
        "temperature": DEFAULT_TEMPERATURE,
        "stream": DEFAULT_STREAM
    }

    if options.isSome:
        let opts = options.get()
        
        if opts.temperature.isSome:
            requestBody["temperature"] = %opts.temperature.get()
            
        if opts.max_tokens.isSome:
            requestBody["max_tokens"] = %opts.max_tokens.get()
            
        if opts.stream.isSome:
            requestBody["stream"] = %opts.stream.get()
            
        if opts.structuredResponse.isSome:
            requestBody["response_format"] = opts.structuredResponse.get()

    if logger.isSome:
        let loggerFunc = logger.get()
        loggerFunc(fmt"запрос: {requestBody}")
    
    return self.getCompletions($requestBody, logger)

# Создает новый API для работы с ИИ в формате с OpenAI
proc newOpenAiApi*(baseUrl: string, headers: HttpHeaders = newHttpHeaders()): OpenAiApi =    
    var api = OpenAiApi(
        baseUrl: baseUrl,
        headers: headers
    )

    # Добавляет заголовок Content-Type
    api.headers.add("Content-Type", "application/json")
    return api

# Добавляет заголовок
proc addHeader*(self: OpenAiApi, key: string, value: string) =
    self.headers.add(key, value)

# Добавляет заголовок Bearer Token
proc addBearerToken*(self: OpenAiApi, token: string) =
    self.headers.add("Authorization", "Bearer " & token)

