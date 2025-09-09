return function(path)
    local tail_path = vim.fn.fnamemodify(path, ":t")

    return {
        {
            id = path,
            name = tail_path,
            path = path,
            range = { 0, 0, 29, 0 },
            type = "file",
        },
        {
            {
                id = path .. '::"namespace 1"',
                name = '"namespace 1"',
                path = path,
                range = { 0, 0, 12, 4 },
                type = "namespace",
            },
            {
                {
                    id = path .. '::"namespace 1"::"nested namespace 1"',
                    name = '"nested namespace 1"',
                    path = path,
                    range = { 1, 4, 11, 8 },
                    type = "namespace",
                },
                {
                    {
                        id = path .. '::"namespace 1"::"nested namespace 1"::("test %d"):format(i)',
                        name = '("test %d"):format(i)',
                        path = path,
                        range = { 3, 12, 5, 16 },
                        type = "test",
                    },
                    -- Two new nodes have been added to the tree for the two parametric tests that were run
                    {
                        {
                            id = path .. '::"namespace 1"::"nested namespace 1"::"test 1"',
                            in_tree = false,
                            name = "test 1",
                            lnum = 4,
                            path = path,
                            type = "test",
                        },
                    },
                    {
                        {
                            id = path .. '::"namespace 1"::"nested namespace 1"::"test 2"',
                            in_tree = false,
                            name = "test 2",
                            lnum = 4,
                            path = path,
                            type = "test",
                        },
                    },
                },
                {
                    {
                        id = path .. '::"namespace 1"::"nested namespace 1"::"test " .. "3"',
                        name = '"test " .. "3"',
                        path = path,
                        range = { 8, 8, 10, 12 },
                        type = "test",
                    },
                },
            },
        },
        {
            {
                id = path .. '::"namespace 2"',
                name = '"namespace 2"',
                path = path,
                range = { 14, 0, 28, 4 },
                type = "namespace",
            },
            {
                {
                    id = path .. '::"namespace 2"::"nested namespace 2 - " .. tostring(i)',
                    name = '"nested namespace 2 - " .. tostring(i)',
                    path = path,
                    range = { 16, 8, 26, 12 },
                    type = "namespace",
                },
                {
                    {
                        id = path
                            .. '::"namespace 2"::"nested namespace 2 - " .. tostring(i)::"some test"',
                        name = '"some test"',
                        path = path,
                        range = { 17, 12, 19, 16 },
                        type = "test",
                    },
                },
                {
                    {
                        id = path
                            .. '::"namespace 2"::"nested namespace 2 - " .. tostring(i)::("test %d"):format(j)',
                        name = '("test %d"):format(j)',
                        path = path,
                        range = { 22, 16, 24, 20 },
                        type = "test",
                    },
                },
            },
        },
    }
end
