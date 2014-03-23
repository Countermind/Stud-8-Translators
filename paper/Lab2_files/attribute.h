#ifndef __ATTRIBUTE_H__
#define __ATTRIBUTE_H__

/**
 * attribute.h
 *   ��������� ������ ��� ����������� ����������, � ��������� ����� ������ �������.
 *
 */

/**
 * ������� �������, ��������������� � ����� ������ �������.
 * ��� �������� � ���� ������ �������� ����������� �������.
 * � �������� ������������ ����� ������������ ��������������
 * ������ ������ ���������.
 */
typedef union Attribute
{
    int    ival;
    char*  sval;
} Attribute;

/**
 * ����������� ������ ����������� ���� ��������� ��������. ������ ������������
 * ��� �������� ���������.  �� ������������, ��� ��� ������������� ���,
 * ����� �������, ����������� �������� �� ����� ���� �������� �����.
 */
typedef struct NamedAttribute
{
    char*     name;
    Attribute val;
} NamedAttribute;

/**
 * ����� ���������. �� ����� ���� ���������� ��� hash-�������.
 * ������, ��������� ������ ��������� ��������� ���������� ���������,
 * �� ����������� ����������� ����� ���� ������ ����������� ���������.
 */
typedef struct AttributeSet
{
    int capacity;               // ��������� ���������� ���������
    int size;			        // ��� ����� ��������� ��������
    NamedAttribute* contents;   // ���� ��������
} AttributeSet;


// +-----------------------------------------------+
// | ��������� ������� ������ � �������� ��������� |
// +-----------------------------------------------+

/**
 * ��������� ����� ����� ���������, ���������� ������� ����������
 * ��������� capacity.
 *
 * � ������ ������ ���������� �������� NULL.
 */
AttributeSet* CreateAttributeSet(int capacity);

/**
 * ������������ ������, ������� ������� ���������
 */
void FreeAttributeSet(AttributeSet* set);

/**
 * �������, �������� �������� �������� ����������� ���� (integer, ...).
 * ����������  1 � ������ ������ � 0 � ������ ������.
 */
int SetAttributeValue(AttributeSet* set, char* name, Attribute att);
int SetAttributeValueInteger(AttributeSet* set, char* name, int ival);
int SetAttributeValueString(AttributeSet* set, char* name, char* sval);

/**
 * ������� ��������� �������� ��������. ���� ��� �������� � �������� ������, 
 * �� ������������ ��������������� ��������.
 */
Attribute GetAttributeValue(AttributeSet* set, char* name);
int GetAttributeValueInteger(AttributeSet* set, char* name);
char* GetAttributeValueString(AttributeSet* set, char* name);

/**
 * ����������, ������� �� � ������ ������� � �������� ������.
 */
int HasAttribute(AttributeSet* set, char* name);

#endif // __ATTRIBUTE_H__ 