# generate_ray.sv
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_x} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {These may be waived because we are intentionally discarding extra fixed point fractional bits}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_y} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {These may be waived because we are intentionally discarding extra fixed point fractional bits}

create_waiver -type LINT -id ASSIGN-6 -rtl_name {offset_x_full} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {These may be waived because we are intentionally only using the upper 16 bits of each offset output}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {offset_y_full} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {These may be waived because we are intentionally only using the upper 16 bits of each offset output}

create_waiver -type LINT -id ASSIGN-1 -rtl_hierarchy {tea_hash} -rtl_file {tea_hash.sv} -user Brian -description {TEA requires all additions to wrap mod 2^32; the carry out of bit 31 is intentionally discarded (matches the reference model)}