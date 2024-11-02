local path = "./test_files/test1_spec.lua"

return {
    {
        id = path,
        name = "test1_spec.lua",
        path = path,
        range = { 0, 0, 22, 0 },
        type = "file",
    },
    {
        {
            id = path .. '::"top-level namespace 1"',
            name = '"top-level namespace 1"',
            path = path,
            range = { 0, 0, 11, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. '::"top-level namespace 1"::"nested namespace 1"',
                name = '"nested namespace 1"',
                path = path,
                range = { 1, 4, 10, 8 },
                type = "namespace",
            },
            {
                {
                    id = path .. '::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                    name = '"test 1"',
                    path = path,
                    range = { 2, 8, 5, 12 },
                    type = "test",
                },
            },
            {
                {
                    id = path .. '::"top-level namespace 1"::"nested namespace 1"::"test 2"',
                    name = '"test 2"',
                    path = path,
                    range = { 7, 8, 9, 12 },
                    type = "test",
                },
            },
        },
    },
    {
        {
            id = path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"',
            name = '"^top-le[ve]l (na*m+e-sp?ac%e) 2$"',
            path = path,
            range = { 13, 0, 21, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                name = '"test 3"',
                path = path,
                range = { 14, 4, 16, 8 },
                type = "test",
            },
        },
        {
            {
                id = path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
                name = '"test 4"',
                path = path,
                range = { 18, 4, 20, 8 },
                type = "test",
            },
        },
    },
}
