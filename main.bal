import ballerina/graphql;
import ballerina/io;
import ballerina/time;

configurable string GITHUB_TOKEN = ?;
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
    RepositoryInfo[] reposFromGraphQl = check getReposFromGraphql("ballerina", excludingOrgs);
    io:println("Retrieved " + reposFromGraphQl.length().toString() + " repositories from the GitHub API.");
    check updateSpreadSheet(reposFromGraphQl);
    io:println("Spreadsheet updated successfully.");
}

isolated function updateSpreadSheet(RepositoryInfo[] fetchedRepos) returns error? {
    sheets:ConnectionConfig spreadsheetConfig = {
        auth: {
            clientId: clientId,
            clientSecret: clientSecret,
            refreshUrl: sheets:REFRESH_URL,
            refreshToken: refreshToken
        }
    };
    sheets:Client spreadsheetClient = check new (spreadsheetConfig);

    // // set the current date
    // string currDate = getTodayDate();
    // error? cellChanged = check spreadsheetClient->setCell(spreadsheetId, SHEET_NAME, 
    //     CURRENT_DATE_CELL, "Today Stats (" +  currDate + ")"
    // );
    // if (cellChanged is error) {
    //     panic error("Error occurred while updating the spreadsheet");
    // }

    // // set the repository count
    // cellChanged = check spreadsheetClient->setCell(
    //     spreadsheetId, 
    //     SHEET_NAME, 
    //     REPO_COUNT_CELL, 
    //     response.data.search.repositoryCount
    // );
    // if (cellChanged is error) {
    //     panic error("Error occurred while updating the spreadsheet.");
    // }

    // // update the history
    // sheets:Cell updatingInfo = check spreadsheetClient->getCell(spreadsheetId, REPO_COUNT_HISTORY_SHEET_NAME, HISTORY_CELL_RANGE_INFO_CELL);
    // string|decimal|int updatingRange = updatingInfo.value;
    // if (updatingRange is string) {
    //     sheets:Range range = check spreadsheetClient->getRange(spreadsheetId, REPO_COUNT_HISTORY_SHEET_NAME, updatingRange);
    //     range.values = [[currDate, response.data.search.repositoryCount]];
    //     cellChanged = check spreadsheetClient->setRange(spreadsheetId, REPO_COUNT_HISTORY_SHEET_NAME, range, "USER_ENTERED");
    //     if (cellChanged is error) {
    //         panic error("Error occurred while updating the spreadsheet.");
    //     }
    //     // update the range info for the next update
    //     string startCell = updatingRange.substring(0, 2);
    //     startCell = startCell[0] + (check int:fromString(startCell[1]) + 1).toString();
    //     string endCell = updatingRange.substring(3);
    //     endCell = endCell[0] + (check int:fromString(endCell[1]) + 1).toString();
    //     string newRange = startCell + ":" + endCell;
    //     cellChanged = check spreadsheetClient->setCell(spreadsheetId, REPO_COUNT_HISTORY_SHEET_NAME, HISTORY_CELL_RANGE_INFO_CELL, newRange);
    //     if (cellChanged is error) {
    //         panic error("Error occurred while updating the spreadsheet.");
    //     }
    // } else {
    //     panic error("Illegal state!");
    // }


    // // set the top repositories in the spreadsheet
    // int|error startingRow = int:fromString(TOP_REPO_START_CELL[1]);
    // if (startingRow is error) {
    //     panic error("Illegal state!");
    // }
    // int|error topRepoCount = int:fromString(TOP_REPO_COUNT);
    // if (topRepoCount is error) {
    //     panic error("Illegal state!");
    // }
    // cellChanged = check spreadsheetClient->setCell(
    //     spreadsheetId, SHEET_NAME, TOP_REPO_HEADER_CELL, 
    //     "Top starred " + TOP_REPO_COUNT + " repositories"
    // );
    // if (cellChanged is error) {
    //     panic error("Error occurred while updating the spreadsheet");
    // }

    // string rangeStr = TOP_REPO_START_CELL + ":" + TOP_REPO_END_COLUMN + (topRepoCount + startingRow).toString();
    // // clear the range of cells first
    // string clearingRangeStr = TOP_REPO_START_CELL + ":" + TOP_REPO_END_COLUMN + (startingRow + 100).toString();
    // cellChanged = check spreadsheetClient->clearRange(spreadsheetId, SHEET_NAME, clearingRangeStr);
    // if (cellChanged is error) {
    //     panic error("Error occurred while updating the spreadsheet");
    // }

    // sheets:Range range = check spreadsheetClient->getRange(spreadsheetId, SHEET_NAME, rangeStr);
    // range.values = response.data.search.edges.map((edge) => [
    //     edge.node.owner.login,  
    //     edge.node.name, 
    //     edge.node.url,
    //     edge.node.stargazerCount
    // ]);
    // cellChanged = check spreadsheetClient->setRange(spreadsheetId, SHEET_NAME, range);
    // if (cellChanged is error) {
    //     panic error("Error occurred while updating the spreadsheet.");
    // }

}

isolated function getTodayDate() returns string {

    // set the current date
    string currDate = time:utcToString(time:utcNow());
    int? index = currDate.indexOf("T");
    if (index is int) {
        currDate = currDate.substring(0, index);
    }
    return currDate;
}

isolated function getReposFromGraphql(string language, string[] excludingOrgs) returns RepositoryInfo[]|error {
    graphql:Client github = check new ("https://api.github.com/graphql", {
        auth: {
            token : GITHUB_TOKEN
        }
    });
    return check fetchRepos(language, excludingOrgs, "desc", github, [], int:MAX_VALUE);
}

isolated function fetchRepos(string language, string[] excludingOrgs, string ascOrDesc, graphql:Client githubClient, 
                            RepositoryInfo[] filteringRepos, int remainingRepoCount) returns RepositoryInfo[]|error {
    if (remainingRepoCount <= 0) {
        return filteringRepos;
    }
    string repoFilter = string:'join(" ", ...filteringRepos.'map((repo) => "-repo:" + repo.owner + "/" + repo.name));
    string filteredQuery = buildQuery(language, excludingOrgs, 100, ascOrDesc, repoFilter);
    QueryResponse|error response = githubClient->execute(filteredQuery);
    if (response is error) {
        io:println(response.toString());
        return response;
    }
    RepositoryInfo[] repos = extractReposFromResponse(response);
    from var repo in repos
    do {
        filteringRepos.push(repo);
    };
    int totalRepoCount = response.data.search.repositoryCount;
    
    if (response.data.search.pageInfo.hasNextPage) {
        //if has next page, then cursot is not null
        string? cursor = response.data.search.pageInfo.endCursor;
        while (true) {
            string newQuery = buildPaginationQuery(language, excludingOrgs, 100, <string>cursor, ascOrDesc, repoFilter);
            QueryResponse newResponse = check githubClient->execute(newQuery);
            RepositoryInfo[] nextSetOfRepos = extractReposFromResponse(newResponse);
            from var repo in nextSetOfRepos
            do {
                filteringRepos.push(repo);
            };

            totalRepoCount = totalRepoCount - 100;
            if (newResponse.data.search.pageInfo.hasNextPage) {
                cursor = newResponse.data.search.pageInfo.endCursor;
            } else {
                break;
            }
        }
    }
    io:println("filtering repos count: " + filteringRepos.length().toString());
    return check fetchRepos(language, excludingOrgs, ascOrDesc, githubClient, filteringRepos, totalRepoCount);
}

isolated function extractReposFromResponse(QueryResponse response) returns RepositoryInfo[] {
    RepositoryInfo[] repos = from var edge in response.data.search.edges
        select {
            id: edge.node.id,
            owner: edge.node.owner.login,
            name: edge.node.name,
            url: edge.node.url,
            stargazerCount: edge.node.stargazerCount
        };
    return repos;
}

