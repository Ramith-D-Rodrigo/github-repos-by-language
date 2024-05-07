import ballerina/graphql;
import ballerina/io;
import ballerinax/googleapis.sheets;
import ballerina/time;

configurable string GITHUB_TOKEN = ?;
configurable string CLIENT_ID = ?;
configurable string CLIENT_SECRET = ?;
configurable string REFRESH_TOKEN = ?;
configurable string SPREADSHEET_ID = ?;
configurable string SHEET_NAME = ?;
configurable string REPO_COUNT_CELL = ?;
configurable string TOP_REPO_START_CELL = ?;
configurable string TOP_REPO_COUNT = ?;
configurable string TOP_REPO_END_COLUMN = ?;
configurable string TOP_REPO_HEADER_CELL = ?;
configurable string CURRENT_DATE_CELL = ?;
configurable string HISTORY_CELL_RANGE_INFO_CELL = ?;
configurable string REPO_COUNT_HISTORY_SHEET_NAME = ?;

public function main(string[] excludingOrgs) returns error? {
    QueryResponse response = check getReposFromGraphql("ballerina", excludingOrgs);
    check updateSpreadSheet(response);
    io:println("Spreadsheet updated successfully.");
}

isolated function updateSpreadSheet(QueryResponse response) returns error? {
    sheets:ConnectionConfig spreadsheetConfig = {
        auth: {
            clientId: CLIENT_ID,
            clientSecret: CLIENT_SECRET,
            refreshUrl: sheets:REFRESH_URL,
            refreshToken: REFRESH_TOKEN
        }
    };
    sheets:Client spreadsheetClient = check new (spreadsheetConfig);

    // set the current date
    string currDate = time:utcToString(time:utcNow());
    int? index = currDate.indexOf("T");
    if (index is int) {
        currDate = currDate.substring(0, index);
    }
    error? cellChanged = check spreadsheetClient->setCell(SPREADSHEET_ID, SHEET_NAME, 
        CURRENT_DATE_CELL, "Today Stats (" +  currDate + ")"
    );
    if (cellChanged is error) {
        panic error("Error occurred while updating the spreadsheet");
    }

    // set the repository count
    cellChanged = check spreadsheetClient->setCell(
        SPREADSHEET_ID, 
        SHEET_NAME, 
        REPO_COUNT_CELL, 
        response.data.search.repositoryCount
    );
    if (cellChanged is error) {
        panic error("Error occurred while updating the spreadsheet.");
    }

    // update the history
    sheets:Cell updatingInfo = check spreadsheetClient->getCell(SPREADSHEET_ID, REPO_COUNT_HISTORY_SHEET_NAME, HISTORY_CELL_RANGE_INFO_CELL);
    string|decimal|int updatingRange = updatingInfo.value;
    if (updatingRange is string) {
        sheets:Range range = check spreadsheetClient->getRange(SPREADSHEET_ID, REPO_COUNT_HISTORY_SHEET_NAME, updatingRange);
        range.values = [[currDate, response.data.search.repositoryCount]];
        cellChanged = check spreadsheetClient->setRange(SPREADSHEET_ID, REPO_COUNT_HISTORY_SHEET_NAME, range, "USER_ENTERED");
        if (cellChanged is error) {
            panic error("Error occurred while updating the spreadsheet.");
        }
        // update the range info for the next update
        string startCell = updatingRange.substring(0, 2);
        startCell = startCell[0] + (check int:fromString(startCell[1]) + 1).toString();
        string endCell = updatingRange.substring(3);
        endCell = endCell[0] + (check int:fromString(endCell[1]) + 1).toString();
        string newRange = startCell + ":" + endCell;
        cellChanged = check spreadsheetClient->setCell(SPREADSHEET_ID, REPO_COUNT_HISTORY_SHEET_NAME, HISTORY_CELL_RANGE_INFO_CELL, newRange);
        if (cellChanged is error) {
            panic error("Error occurred while updating the spreadsheet.");
        }
    } else {
        panic error("Illegal state!");
    }


    // set the top repositories in the spreadsheet
    int|error startingRow = int:fromString(TOP_REPO_START_CELL[1]);
    if (startingRow is error) {
        panic error("Illegal state!");
    }
    int|error topRepoCount = int:fromString(TOP_REPO_COUNT);
    if (topRepoCount is error) {
        panic error("Illegal state!");
    }
    cellChanged = check spreadsheetClient->setCell(
        SPREADSHEET_ID, SHEET_NAME, TOP_REPO_HEADER_CELL, 
        "Top starred " + TOP_REPO_COUNT + " repositories"
    );
    if (cellChanged is error) {
        panic error("Error occurred while updating the spreadsheet");
    }

    string rangeStr = TOP_REPO_START_CELL + ":" + TOP_REPO_END_COLUMN + (topRepoCount + startingRow).toString();
    // clear the range of cells first
    string clearingRangeStr = TOP_REPO_START_CELL + ":" + TOP_REPO_END_COLUMN + (startingRow + 100).toString();
    cellChanged = check spreadsheetClient->clearRange(SPREADSHEET_ID, SHEET_NAME, clearingRangeStr);
    if (cellChanged is error) {
        panic error("Error occurred while updating the spreadsheet");
    }

    sheets:Range range = check spreadsheetClient->getRange(SPREADSHEET_ID, SHEET_NAME, rangeStr);
    range.values = response.data.search.edges.map((edge) => [
        edge.node.owner.login,  
        edge.node.name, 
        edge.node.url,
        edge.node.stargazerCount
    ]);
    cellChanged = check spreadsheetClient->setRange(SPREADSHEET_ID, SHEET_NAME, range);
    if (cellChanged is error) {
        panic error("Error occurred while updating the spreadsheet.");
    }

}

isolated function getReposFromGraphql(string language, string[] excludingOrgs) returns QueryResponse|error {
    graphql:Client github = check new ("https://api.github.com/graphql", {
        auth: {
            token : GITHUB_TOKEN
        }
    });
    string filteredQuery = buildQuery(language, excludingOrgs, TOP_REPO_COUNT);
    return check github->execute(filteredQuery);
}

