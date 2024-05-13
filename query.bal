type Node record {
    string id;
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
    PageInfo pageInfo;
    EdgesItem[] edges;
};

type PageInfo record {
    boolean hasNextPage;
    string? endCursor;
};

type Data record {
    Search search;
};

type QueryResponse record {
    Data data;
};

type RepositoryInfo record {
    string id;
    string name;
    int stargazerCount;
    string url;
    string owner;
};

isolated function buildQuery(string language, string[] excludingOrgs, int paginationCount, 
                                string starAscOrDesc, string otherFilers = "") returns string {
    string filterStr = string:'join(" ", ...excludingOrgs.'map((org) => string `-org:${org}`));
    string filteredQuery = string `
        query {
            search(
                type: REPOSITORY, 
                query: "language:${language} fork:false ${filterStr} sort:stars-${starAscOrDesc} ${otherFilers}", 
                first: ${paginationCount}   
            ) {
                repositoryCount
                pageInfo {
                    hasNextPage
                    endCursor
                }
                edges {
                    node {
                        ... on Repository {
                            id
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

isolated function buildPaginationQuery(string language, string[] excludingOrgs, int paginationCount, 
                                        string cursor, string starAscOrDesc, string otherFilers = "") returns string {
    string filterStr = string:'join(" ", ...excludingOrgs.'map((org) => string `-org:${org}`));
    string filteredQuery = string `
        query {
            search(
                type: REPOSITORY, 
                query: "language:${language} fork:false ${filterStr} sort:stars-${starAscOrDesc} ${otherFilers}", 
                first: ${paginationCount},
                after: "${cursor}"
            ) {
                repositoryCount
                pageInfo {
                    hasNextPage
                    endCursor
                }
                edges {
                    node {
                        ... on Repository {
                            id
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