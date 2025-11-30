local path = "./test_files/nio_async_spec.lua"

return {
    {
        id = path,
        name = "nio_async_spec.lua",
        path = path,
        range = { 0, 0, 42, 0 },
        type = "file",
    },
    {
        {
            id = path .. "::nio async tests",
            name = "nio async tests",
            path = path,
            range = { 6, 0, 41, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. "::nio async tests::async test 1",
                name = "async test 1",
                path = path,
                range = { 14, 4, 18, 12 },
                type = "test",
            },
        },
        {
            {
                id = path .. "::nio async tests::async test 2",
                name = "async test 2",
                path = path,
                range = { 20, 4, 33, 8 },
                type = "test",
            },
        },
        {
            {
                id = path .. "::nio async tests::async test 3",
                name = "async test 3",
                path = path,
                range = { 35, 4, 39, 12 },
                type = "test",
            },
        },
    },
}
