/**
 * attribute.c
 *   Реализация функциональности структур данных для манипуляции атрибутами,
 *   в частности узлов дерева разбора.
 *
 */

#ifndef YYBISON
#include "attribute.h"
#endif
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

/**
 * Отыскивает индекс атрибута в наборе. Если он не найден, то возвращается -1.
 */
static int FindAttribute(AttributeSet* set, char* name)
{
    int i;
    for (i = 0; i < set->size; ++i)
    {
        if (0 == strcmp(set->contents[i].name, name))
        {
           return i;
        }
    }
  // Этот оператор выполняется, если предыдущий цикл был полностью выполнен.
  return -1;
}


/**
 * Получение атрибута.
 */
Attribute GetAttributeValue(AttributeSet* set, char* name)
{
    return set->contents[FindAttribute(set, name)].val;
}

/**
 * Установка значения атрибута.
 */
int SetAttributeValue(AttributeSet* set, char* name, Attribute att)
{
    // Смотрим, есть ли такой атрибут в наборе.
    int index = FindAttribute(set, name);

    // Если есть, то изменяем значение.
    if (index >= 0)
    {
        set->contents[index].val = att;
        return 1;
    }

    // Если нет места для нового атрибута, то сдаемся.
    if (set->size >= set->capacity)
        return 0;

    // Размещаем новый атрибут в наборе.
    index = (set->size)++;
    set->contents[index].name = name;
    set->contents[index].val = att;

    return 1;
}


// +------------------------+
// | Экспортируемые функции |
// +------------------------+

void FreeAttributeSet(AttributeSet* set)
{
    if (0 < set->capacity)
	{
		free(set->contents);
		set->contents = NULL;
	}
    set->size = 0;
    set->capacity = 0;
    free(set);
	set = NULL;
}

int GetAttributeValueInteger (AttributeSet* set, char* name)
{
    return (GetAttributeValue(set, name)).ival;
}

char* GetAttributeValueString(AttributeSet* set, char* name)
{
    return (GetAttributeValue(set, name)).sval;
}

int HasAttribute(AttributeSet* set, char* name)
{
    return (FindAttribute(set, name) != -1);
}

AttributeSet* CreateAttributeSet(int capacity)
{
    int i;
    AttributeSet* result = (AttributeSet*) malloc(sizeof(AttributeSet));
    if (result == NULL)
        return NULL;
    if (capacity > 0)
    {
        result->contents = (NamedAttribute*) malloc(capacity * sizeof(NamedAttribute));
        if (result->contents == NULL)
        {
            free(result);
            return NULL;
        }
        for (i = 0; i < capacity; ++i)
            result->contents[i].name = "";
    }
    result->capacity = capacity;
    result->size = 0;
    return result;
}

int SetAttributeValueInteger(AttributeSet* set, char* name, int ival)
{
    // Можно воспользоваться приведением типов, но 
    // мы пробуем более безопасный способ.
    Attribute att;
    att.ival = ival;
    return SetAttributeValue(set, name, att);
}

int SetAttributeValueString(AttributeSet* set, char* name, char* sval)
{
    Attribute att;
    att.sval = sval;
    return SetAttributeValue(set, name, att);
}
