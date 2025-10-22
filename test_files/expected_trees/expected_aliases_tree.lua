local path = "./test_files/aliases_spec.lua"

return {
    {
        id = path,
        name = "aliases_spec.lua",
        path = path,
        range = { 0, 0, 42, 0 },
        type = "file",
    },
    {
        {
            id = path .. "::describe",
            name = "describe",
            path = path,
            range = { 2, 0, 41, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. "::describe::context",
                name = "context",
                path = path,
                range = { 3, 4, 7, 8 },
                type = "namespace",
            },
            {
                {
                    id = path .. "::describe::context::it",
                    name = "it",
                    path = path,
                    range = { 4, 8, 6, 12 },
                    type = "test",
                },
            },
        },
        {
            {
                id = path .. "::describe::insulate",
                name = "insulate",
                path = path,
                range = { 9, 4, 13, 8 },
                type = "namespace",
            },
            {
                {
                    id = path .. "::describe::insulate::spec",
                    name = "spec",
                    path = path,
                    range = { 10, 8, 12, 12 },
                    type = "test",
                },
            },
        },
        {
            {
                id = path .. "::describe::expose",
                name = "expose",
                path = path,
                range = { 15, 4, 19, 8 },
                type = "namespace",
            },
            {
                {
                    id = path .. "::describe::expose::test",
                    name = "test",
                    path = path,
                    range = { 16, 8, 18, 12 },
                    type = "test",
                },
            },
        },
        {
            {
                id = path .. "::describe::async it",
                name = "async it",
                path = path,
                range = { 21, 4, 26, 5 },
                type = "test",
            },
        },
        {
            {
                id = path .. "::describe::async spec",
                name = "async spec",
                path = path,
                range = { 28, 4, 33, 5 },
                type = "test",
            },
        },
        {
            {
                id = path .. "::describe::async test",
                name = "async test",
                path = path,
                range = { 35, 4, 40, 5 },
                type = "test",
            },
        },
    },
}
