type Node record {
    string name;
    int stargazerCount;
    string url;
    Owner owner;
};

type Owner record {
    string login;
};

type EdgesItem record {
    Node node;
};

type Search record {
    int repositoryCount;
    EdgesItem[] edges;
};

type Data record {
    Search search;
};

type QueryResponse record {
    Data data;
};

isolated function buildQuery(string language, string[] excludingOrgs, string topStarredReposCount) returns string {
    string filterStr = string:'join(" ", ...excludingOrgs.'map((org) => string `-org:${org}`));
    string filteredQuery = string `
        query {
            search(
                type: REPOSITORY, 
                query: "language:${language} fork:false ${filterStr} sort:stars-desc", 
                first: ${topStarredReposCount}   
            ) {
                repositoryCount
                edges {
                    node {
                        ... on Repository {
                            name
                            stargazerCount
                            url
                            owner {
                                login
                            }
                        }
                    }
                }
            }
        }
    `;
    return filteredQuery;
}