return {
    example = { -- animation_set
        wide = { -- animation_id --> should match atlas animation group name
            -32,
            0,
            keep_cursor = {
                'tall'
            }
        },
        tall = {
            0,
            32,
            keep_cursor = {
                'wide'
            }
        }
    }
}