
module dart.record;

class ColumnInfo {

    string name;

    bool notNull;
    bool autoIncrement;

    uint maxLength;

}

class Record {

    protected {

        ColumnInfo[string] _columns;

        /**
         * Gets a column definition, by name.
         **/
        ColumnInfo _getColumnInfo(string name) {
            return _columns[name];
        }

        /**
         * Adds a column definition to this record.
         **/
        void _addColumnInfo(ColumnInfo ci) {
            _columns[ci.name] = ci;
        }

    }

}

mixin template ActiveRecord() {

    /**
     * Gets an object by its primary key.
     **/
    static string get(KT)(KT key) {
        return null;
    }

    /**
     * Finds matching objects, by column values.
     **/
    static string[] find(KT)(KT[string] key...) {
        return null;
    }

    /**
     * Creates this object in the database,
     * if it does not yet exist.
     **/
    void create() {

    }

    /**
     * Saves this object in the database,
     * if it already exists.
     **/
    void save() {

    }

    /**
     * Updates a single column in the database.
     **/
    void update(string name) {

    }

    /**
     * Removes this object from the database,
     * if it already exists.
     **/
    void remove() {

    }

}
