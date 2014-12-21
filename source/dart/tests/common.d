
module dart.tests.common;

import dart.record;

@Table("test_record")
class TestRecord : Record {

    mixin ActiveRecord!(TestRecord);

    @Id
    int id;

    @Column
    string name;

    static this() {
        _setMysqlDB(new MysqlDB("127.0.0.1", "test", "test", "test"));
    }

}

unittest {

    auto record = TestRecord.get(1);
    assert(record !is null);
    assert(record.id == 1);

}
