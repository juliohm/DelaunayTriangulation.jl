"""
add_point!(tri::Triangulation, new_point[, new_point_y];
    point_indices=get_vertices(tri),
    m=default_num_samples(length(point_indices)),
    try_points=(),
    rng::AbstractRNG=Random.default_rng(),
    initial_search_point=integer_type(tri)(select_initial_point(get_points(tri),new_point;point_indices,m,try_points,rng)),
    update_representative_point=false)

Adds the point `new_point` to the triangulation `tri`.

# Arguments 
- `tri::Triangulation`: The [`Triangulation`](@ref).
- `new_point[, new_point_y]`: The point to add. This `new_point` can be an integer, in which case `get_point(tri, new_point)` is added. If `new_point` is just a set of coordinates, we add that into `tri` via [`push_point!`](@ref) and then add that index into `tri`. Lastly, if we provide `(new_point, new_point_y)`, then the point is treated as this `Tuple` and inserted.

# Keyword Arguments 
- `point_indices=each_solid_vertex(tri)`: The indices of the non-ghost points in the triangulation.
- `m=default_num_samples(length(point_indices))`: The number of points to sample from `point_indices` to use as the initial search point.
- `try_points=()`: A list of points to try as the initial search point in addition to those sampled.
- `rng::AbstractRNG=Random.default_rng()`: The random number generator to use.
- `initial_search_point=integer_type(tri)(select_initial_point(get_points(tri),new_point;point_indices,m,try_points,rng))`: The initial search point to use. If this is not provided, then we use [`select_initial_point`](@ref) to select one.
- `update_representative_point=false`: Whether to update the representative point list after adding the new point.
"""
function add_point!(tri::Triangulation, new_point;
    point_indices=each_solid_vertex(tri),
    m=default_num_samples(length(point_indices)),
    try_points=(),
    rng::AbstractRNG=Random.default_rng(),
    initial_search_point=integer_type(tri)(select_initial_point(get_points(tri),new_point;point_indices,m,try_points,rng)),
    update_representative_point=false)
    if !(new_point isa Integer)
        push_point!(tri, new_point)
        new_point = num_points(tri)
    end
    add_point_bowyer_watson!(tri, new_point, initial_search_point, rng, update_representative_point)
    return nothing
end

function add_point!(tri::Triangulation, new_point_x, new_point_y;
    point_indices=get_vertices(tri),
    m=default_num_samples(length(point_indices)),
    try_points=(),
    rng::AbstractRNG=Random.default_rng(),
    initial_search_point=integer_type(tri)(select_initial_point(get_points(tri),(new_point_x, new_point_y); point_indices, m, try_points, rng)),
    update_representative_point=false)
    push_point!(tri, new_point_x, new_point_y)
    return add_point!(tri, num_points(tri); point_indices=point_indices, m=m, try_points=try_points, rng=rng, initial_search_point=initial_search_point, update_representative_point=update_representative_point)
end