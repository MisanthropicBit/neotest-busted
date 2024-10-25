return {
    {
        id = "./test_files/parametric_tests_spec.lua",
        name = "parametric_tests_spec.lua",
        path = "./test_files/parametric_tests_spec.lua",
        range = { 0, 0, 29, 0 },
        type = "file",
    },
    {
        {
            id = './test_files/parametric_tests_spec.lua::"namespace 1"',
            name = '"namespace 1"',
            path = "./test_files/parametric_tests_spec.lua",
            range = { 0, 0, 12, 4 },
            type = "namespace",
        },
        {
            {
                id = './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"',
                name = '"nested namespace 1"',
                path = "./test_files/parametric_tests_spec.lua",
                range = { 1, 4, 11, 8 },
                type = "namespace",
            },
            {
                {
                    id =
                    './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::("test %d"):format(i)',
                    name = '("test %d"):format(i)',
                    path = "./test_files/parametric_tests_spec.lua",
                    range = { 3, 12, 5, 16 },
                    type = "test",
                },
            },
            {
                {
                    id =
                    './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::"test " .. "3"',
                    name = '"test " .. "3"',
                    path = "./test_files/parametric_tests_spec.lua",
                    range = { 8, 8, 10, 12 },
                    type = "test",
                },
            },
        },
    },
    {
        {
            id = './test_files/parametric_tests_spec.lua::"namespace 2"',
            name = '"namespace 2"',
            path = "./test_files/parametric_tests_spec.lua",
            range = { 14, 0, 28, 4 },
            type = "namespace",
        },
        {
            {
                id =
                './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)',
                name = '"nested namespace 2 - " .. tostring(i)',
                path = "./test_files/parametric_tests_spec.lua",
                range = { 16, 8, 26, 12 },
                type = "namespace",
            },
            {
                {
                    id =
                    './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::"some test"',
                    name = '"some test"',
                    path = "./test_files/parametric_tests_spec.lua",
                    range = { 17, 12, 19, 16 },
                    type = "test",
                },
            },
            {
                {
                    id =
                    './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::("test %d"):format(j)',
                    name = '("test %d"):format(j)',
                    path = "./test_files/parametric_tests_spec.lua",
                    range = { 22, 16, 24, 20 },
                    type = "test",
                },
            },
        },
    },
}
