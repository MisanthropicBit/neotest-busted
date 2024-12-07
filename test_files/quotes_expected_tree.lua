local path = "./test_files/quotes_spec.lua"

return {
    {
        id = path,
        name = "quotes_spec.lua",
        path = path,
        range = { 0, 0, 11, 0 },
        type = "file",
    },
    {
        {
            id = path .. '::"quotes"',
            name = '"quotes"',
            path = path,
            range = { 0, 0, 10, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. "::\"quotes\"::'single quotes test'",
                name = "'single quotes test'",
                path = path,
                range = { 2, 4, 5, 8 },
                type = "test",
            },
        },
        {
            {
                id = path .. '::"quotes"::[[literal quotes test]]',
                name = "[[literal quotes test]]",
                path = path,
                range = { 7, 4, 9, 8 },
                type = "test",
            },
        },
    },
}
