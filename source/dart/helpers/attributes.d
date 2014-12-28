
module dart.helpers.attributes;

/**
 * Table annotation type.
 **/
struct Table {
    /**
     * Specifies the name of the table.
     * (Optional) Default: Name of annotated type.
     **/
    string name;
}

/**
 * Column annotation type.
 **/
struct Column {
    /**
     * Specifies the name of the column.
     * (Optional) Default: Name of annotated field.
     **/
    string name;
}

/**
 * MaxLength annotation type.
 *
 * This annotation is only meaningful for types that declare
 * a length property, and for fields of an array type.
 **/
struct MaxLength {
    /**
     * Specifies the maximum length of the column.
     **/
    int maxLength;
}

/**
 * Id annotation type.
 * Indicates that this column is the primary Id.
 **/
enum Id;

/**
 * Nullable annotation type.
 * Indicates that this column may be null.
 **/
enum Nullable;

/**
 * Compound annotation type.
 * Indicates that this type's fields a compound part of
 * record types that use include it.
 **/
enum Compound;

/**
 * Embedded annotation type.
 * Indicates that this field is a composite value, consisting
 * of column definitions of its compound type.
 **/
enum Embedded;

/**
 * AutoIncrement annotation type.
 * Indicates that this column is auto incremented.
 *
 * This annotation is only meaningful for Id columns,
 * and cannot be assigned to non-numeric types.
 **/
enum AutoIncrement;
