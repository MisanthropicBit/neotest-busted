local path = "./test_files/error_spec.lua"

return {
    {
        id = path,
        name = "error_spec.lua",
        path = path,
        range = { 0, 0, 5, 0 },
        type = "file",
    },
    {
        {
            id = path .. "::describe",
            name = "describe",
            path = path,
            range = { 0, 0, 4, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. "::describe::test",
                name = "test",
                path = path,
                range = { 1, 4, 3, 8 },
                type = "test",
            },
        },
    },
}
