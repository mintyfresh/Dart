
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

    auto record = new TestRecord;
    record.id = 1;
    record.name = "Test";
    record.create;

    record = TestRecord.get(1);
    assert(record !is null);
    assert(record.id == 1);
    assert(record.name == "Test");

    auto records = TestRecord.find(["name": "Test"]);
    assert(records.length == 1);
    assert(records[0].name == "Test");

    record.remove;

}
