local function compare_test_positions(positions, expected_positions)
    assert.are.same(#positions, #expected_positions)

    for idx = 1, #positions, 1 do
        local position = positions[idx]
        local expected_position = expected_positions[idx]

        if position.id ~= nil then
            assert.are.same(position.name, expected_position.name)
            assert.are.same(position.type, expected_position.type)
        else
            compare_test_positions(position, expected_position)
        end
    end
end

return compare_test_positions
