local path = "./test_files/test1_spec.lua"

return {
    {
        id = path,
        name = "test1_spec.lua",
        path = path,
        range = { 0, 0, 21, 0 },
        type = "file",
    },
    {
        {
            id = path .. '::"top-level namespace 1"',
            name = '"top-level namespace 1"',
            path = path,
            range = { 0, 0, 10, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. '::"top-level namespace 1"::"nested namespace 1"',
                name = '"nested namespace 1"',
                path = path,
                range = { 1, 4, 9, 8 },
                type = "namespace",
            },
            {
                {
                    id = path .. '::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                    name = '"test 1"',
                    path = path,
                    range = { 2, 8, 4, 12 },
                    type = "test",
                },
            },
            {
                {
                    id = path .. '::"top-level namespace 1"::"nested namespace 1"::"test 2"',
                    name = '"test 2"',
                    path = path,
                    range = { 6, 8, 8, 12 },
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
            range = { 12, 0, 20, 4 },
            type = "namespace",
        },
        {
            {
                id = path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                name = '"test 3"',
                path = path,
                range = { 13, 4, 15, 8 },
                type = "test",
            },
        },
        {
            {
                id = path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
                name = '"test 4"',
                path = path,
                range = { 17, 4, 19, 8 },
                type = "test",
            },
        },
    },
}
