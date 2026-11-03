# generate_ray.sv
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_x} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {This may be waived because we are intentionally discarding extra fixed point fractional bits}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_y} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {This may be waived because we are intentionally discarding extra fixed point fractional bits}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {offset_x_full} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {This may be waived because we are intentionally only using the upper 16 bits of each offset output}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {offset_y_full} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {This may be waived because we are intentionally only using the upper 16 bits of each offset output}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {norm_div_signed} -rtl_hierarchy {generate_ray_norm} -rtl_file {generate_ray_norm.sv} -user Brian -description {This may be waived because the signal is intentionally trimmed in the rtl}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {s} -rtl_hierarchy {generate_ray_norm} -rtl_file {generate_ray_norm.sv} -user Brian -description {This may be waived because the signal is intentionally trimmed in the rtl}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {x_norm_full} -rtl_hierarchy {generate_ray_norm} -rtl_file {generate_ray_norm.sv} -user Brian -description {This may be waived because the signal is intentionally trimmed in the rtl}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {y_norm_full} -rtl_hierarchy {generate_ray_norm} -rtl_file {generate_ray_norm.sv} -user Brian -description {This may be waived because the signal is intentionally trimmed in the rtl}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {z_norm_full} -rtl_hierarchy {generate_ray_norm} -rtl_file {generate_ray_norm.sv} -user Brian -description {This may be waived because the signal is intentionally trimmed in the rtl}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {camera_space_x_d} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {SQ2.16 -> SQ1.16 trim; bit 18 is a sign copy since |x| < sqrt(3); enforced by a_camera_space_fits_sq1_16}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {camera_space_y_d} -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {SQ2.16 -> SQ1.16 trim; bit 18 is a sign copy since |x| < sqrt(3); enforced by a_camera_space_fits_sq1_16}

create_waiver -type LINT -id ASSIGN-1 -rtl_hierarchy {tea_hash} -rtl_file {tea_hash.sv} -user Brian -description {TEA requires all additions to wrap mod 2^32; the carry out of bit 31 is intentionally discarded (matches the reference model)}
create_waiver -type LINT -id ASSIGN-1 -rtl_hierarchy {generate_ray_norm} -rtl_file {generate_ray_norm.sv} -user Brian -description {Signal s has range [1, 4) by range proof; upper sum bits intentionally unused, trimmed at s_trimmed.}
create_waiver -type LINT -id ASSIGN-1 -rtl_hierarchy {generate_ray} -rtl_file {generate_ray.sv} -user Brian -description {SQ2.16 -> SQ1.16 trim; bit 18 is a sign copy since |x| < sqrt(3); enforced by a_camera_space_fits_sq1_16}

# ray_dir_inverse.sv
create_waiver -type LINT -id ASSIGN-6 -rtl_name {abs_dir_x} -rtl_hierarchy {ray_dir_inverse} -rtl_file {ray_dir_inverse.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {abs_dir_y} -rtl_hierarchy {ray_dir_inverse} -rtl_file {ray_dir_inverse.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {abs_dir_z} -rtl_hierarchy {ray_dir_inverse} -rtl_file {ray_dir_inverse.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {abs_inv_m_x} -rtl_hierarchy {ray_dir_inverse} -rtl_file {ray_dir_inverse.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {abs_inv_m_y} -rtl_hierarchy {ray_dir_inverse} -rtl_file {ray_dir_inverse.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {abs_inv_m_z} -rtl_hierarchy {ray_dir_inverse} -rtl_file {ray_dir_inverse.sv} -user Brian -description {This signal is intentionally trimmed}

# ray_bbox_intersect.sv
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_x_t0_shifted} -rtl_hierarchy {ray_bbox_intersect} -rtl_file {ray_bbox_intersect.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_x_t1_shifted} -rtl_hierarchy {ray_bbox_intersect} -rtl_file {ray_bbox_intersect.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_y_t0_shifted} -rtl_hierarchy {ray_bbox_intersect} -rtl_file {ray_bbox_intersect.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_y_t1_shifted} -rtl_hierarchy {ray_bbox_intersect} -rtl_file {ray_bbox_intersect.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_z_t0_shifted} -rtl_hierarchy {ray_bbox_intersect} -rtl_file {ray_bbox_intersect.sv} -user Brian -description {This signal is intentionally trimmed}
create_waiver -type LINT -id ASSIGN-6 -rtl_name {mult_result_z_t1_shifted} -rtl_hierarchy {ray_bbox_intersect} -rtl_file {ray_bbox_intersect.sv} -user Brian -description {This signal is intentionally trimmed}
