local path = "./test_files/quotes_spec.lua"

return {
    {
        id = path,
        name = "quotes_spec.lua",
        path = path,
        range = { 0, 0, 9, 0 },
        type = "file",
    },
    {
        {
            id = path .. '::"quotes"',
            name = '"quotes"',
            path = path,
            range = { 0, 0, 8, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. "::\"quotes\"::'single quotes test'",
                name = "'single quotes test'",
                path = path,
                range = { 1, 4, 3, 8 },
                type = "test",
            },
        },
        {
            {
                id = path .. '::"quotes"::[[literal quotes test]]',
                name = "[[literal quotes test]]",
                path = path,
                range = { 5, 4, 7, 8 },
                type = "test",
            },
        },
    },
}
