local path = "./test_files/pending_spec.lua"

return {
    {
        id = path,
        name = "pending_spec.lua",
        path = path,
        range = { 0, 0, 13, 0 },
        type = "file",
    },
    {
        {
            id = path .. '::"top-level pending"',
            name = '"top-level pending"',
            path = path,
            range = { 0, 0, 0, 28 },
            type = "test",
        },
    },
    {
        {
            id = path .. '::"pending tests"',
            name = '"pending tests"',
            path = path,
            range = { 2, 0, 12, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. '::"pending tests"::"pending 1"',
                name = '"pending 1"',
                path = path,
                range = { 3, 4, 5, 8 },
                type = "test",
            },
            {
                {
                    id = path .. '::"pending tests"::"pending 1"::"finish this test later"',
                    name = '"finish this test later"',
                    path = path,
                    range = { 4, 8, 4, 41 },
                    type = "test",
                },
            },
        },
        {
            {
                id = path .. '::"pending tests"::"pending 2"',
                name = '"pending 2"',
                path = path,
                range = { 7, 4, 9, 8 },
                type = "test",
            },
            {
                {
                    id = path .. '::"pending tests"::"pending 2"::"this test does not run"',
                    name = '"this test does not run"',
                    path = path,
                    range = { 8, 8, 8, 52 },
                    type = "test",
                },
            },
        },
        {
            {
                id = path .. '::"pending tests"::"pending 3"',
                name = '"pending 3"',
                path = path,
                range = { 11, 4, 11, 24 },
                type = "test",
            },
        },
    },
}
