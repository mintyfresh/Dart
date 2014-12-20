
module dart.record;

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
     * Removes this object from the database,
     * if it already exists.
     **/
    void remove() {

    }

}
