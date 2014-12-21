
module dart.query;

interface QueryBuilder {

    /**
     * Converts the current builder state into a query string.
     **/
    string build();

}
