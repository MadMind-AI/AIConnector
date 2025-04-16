import typetraits, json, tables
import strformat, strutils

import ../common/text

type 
    # Простой тип данных
    SimpleType = SomeInteger | SomeFloat | string | bool

# Получает значения перечисления
proc enumValues(T: typedesc): seq[string] =  
  result = @[]
  for i in ord(low(T)) .. ord(high(T)):
    result.add $T(i)

# Генерирует JSON Schema для простого типа
proc generateJsonSchemaForSimpleType(T: typedesc): JsonNode =
  when T is SomeInteger:
    result = %*{"type": "integer"}
  elif T is SomeFloat:
    result = %*{"type": "number"}
  elif T is string:
    result = %*{"type": "string"}
  elif T is bool:
    result = %*{"type": "boolean"}  

# Генерирует JSON Schema для указанного типа T
proc generateJsonSchemaForType*(T: typedesc): JsonNode =  
  # Проверяем, является ли тип объектом
  when T is object:
    result = %*{
      "type": "object",
      "properties": newJObject(),
      "required": newJArray()
    }

    # Получаем информацию о полях объекта
    for fieldName, fieldValue in T().fieldPairs:
      let schemaProp = result["properties"]
      let required = result["required"]

      # Генерируем схему для каждого поля
      var fieldSchema: JsonNode

      # Определяем тип поля
      when fieldValue is SimpleType:
        fieldSchema = generateJsonSchemaForSimpleType(typeof(fieldValue))      
      elif fieldValue is object:
        # Рекурсивно генерируем схему для вложенных объектов
        fieldSchema = generateJsonSchemaForType(typeof(fieldValue))
      elif fieldValue is tuple:
        fieldSchema = %*{
          "type": "object",
          "properties": newJObject(),
          "required": newJArray()
        }

        let tupleSchemaProp = fieldSchema["properties"]
        let tupleRequired = fieldSchema["required"]

        for fk, fv in fieldValue.fieldPairs:
          tupleSchemaProp[fk] = generateJsonSchemaForType(typeof(fv))
          tupleRequired.add newJString(fk)
      elif fieldValue is seq or fieldValue is array:
        # Обрабатываем массивы
        fieldSchema = %*{
          "type": "array",
          "items": generateJsonSchemaForType(elementType(fieldValue))
        }        
      elif fieldValue is enum:
        fieldSchema = %*{
          "type": "string",
          "enum": enumValues(typeof(fieldValue))
        }                
      else:
        # Для неизвестных типов используем any
        fieldSchema = %*{"type": "any"}    
      
      # Добавляем поле в properties
      schemaProp[fieldName] = fieldSchema
      # Добавляем поле в required
      required.add newJString(fieldName)      
  elif T is SimpleType:
    result = generateJsonSchemaForSimpleType(T)
  else:
    # Для не-объектных типов возвращаем простую схему
    result = %*{"type": "any"}  

# Генерирует JSON Schema
proc generateJsonSchema*(T: typedesc): JsonNode =
  result = %*{      
      "type": "json_schema",                  
      "json_schema": %* {
        "name": fmt"{$T}_response",
        "schema": generateJsonSchemaForType(T)
      } 
    }

# Пример использования
when isMainModule:
  type
    Status = enum
      Active, Inactive    

    City = object
      name: string
      population: int
      country: string

    Person = object
      # Является ли персонаж главным
      isMain*: bool
      # Имя персонажа
      name*: string
      # Фамилия персонажа
      surname*: string
      # Пол персонажа
      sex*: string
      # Возраст персонажа
      age*: int
      # Внешность персонажа
      look*: Text
      # Характеристики персонажа
      character*: Text
      # Мотивация персонажа: инстинкты, желания, цели
      motivation*: Text
      # Память персонажа
      memory*: Text

  var schema = generateJsonSchema(Person)
  echo schema.pretty()  