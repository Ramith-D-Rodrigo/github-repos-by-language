import ballerina/persist as _;


public type Repository record {|
    readonly string id;
    string name;
    string organization;
    string url;
	StarsOnDate[] starsondate;
|};

public type StarsOnDate record {|
    readonly string id;
    Repository repository;
    string date;
    int stars;
|};