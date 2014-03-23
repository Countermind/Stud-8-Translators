#ifndef __ATTRIBUTE_H__
#define __ATTRIBUTE_H__

/**
 * attribute.h
 *   Структуры данных для манипуляции атрибутами, в частности узлов дерева разбора.
 *
 */

/**
 * Простой атрибут, ассоциированный с узлом дерева разбора.
 * Тип атрибута в этом случае придется отслеживать вручную.
 * В качестве альтернативы можно использовать типизированную
 * версию данной структуры.
 */
typedef union Attribute
{
    int    ival;
    char*  sval;
} Attribute;

/**
 * Именованная версия приведенной выше структуры атрибута. Обычно используется
 * для множеств атрибутов.  Мы предполагаем, что имя подразумевает тип,
 * таким образом, именованные атрибуты не имеют явно заданных типов.
 */
typedef struct NamedAttribute
{
    char*     name;
    Attribute val;
} NamedAttribute;

/**
 * Набор атрибутов. Он может быть реализован как hash-таблица.
 * Однако, поскольку обычно требуется небольшое количество атрибутов,
 * то эффективнее использвать всего лишь массив именованных атрибутов.
 */
typedef struct AttributeSet
{
    int capacity;               // Начальное количество атрибутов
    int size;			        // Как много атрибутов хранится
    NamedAttribute* contents;   // Сами атрибуты
} AttributeSet;


// +-----------------------------------------------+
// | Прототипы функций работы с наборами атрибутов |
// +-----------------------------------------------+

/**
 * Создается новый набор атрибутов, количество которых ограничено
 * значением capacity.
 *
 * В случае ошибки возвращает значение NULL.
 */
AttributeSet* CreateAttributeSet(int capacity);

/**
 * Освобждается память, занятая набором атрибутов
 */
void FreeAttributeSet(AttributeSet* set);

/**
 * Функции, задающие значение атрибута конкретного типа (integer, ...).
 * Возвращает  1 в случае успеха и 0 в случае ошибки.
 */
int SetAttributeValue(AttributeSet* set, char* name, Attribute att);
int SetAttributeValueInteger(AttributeSet* set, char* name, int ival);
int SetAttributeValueString(AttributeSet* set, char* name, char* sval);

/**
 * Функции получения значения атрибута. Если нет атрибута с заданным именем, 
 * то возвращается непредсказуемое значение.
 */
Attribute GetAttributeValue(AttributeSet* set, char* name);
int GetAttributeValueInteger(AttributeSet* set, char* name);
char* GetAttributeValueString(AttributeSet* set, char* name);

/**
 * Определяет, имеется ли в наборе атрибут с заданным именем.
 */
int HasAttribute(AttributeSet* set, char* name);

#endif // __ATTRIBUTE_H__ 