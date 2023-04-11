@inline function get_point_order(points, randomise, skip_points, IntegerType::Type{I},
    rng::AbstractRNG=Random.default_rng()) where {I}
    point_indices = convert(Vector{I}, collect(each_point_index(points)))
    randomise && shuffle!(rng, point_indices)
    setdiff!(point_indices, skip_points)
    return point_indices
end

@inline function get_initial_triangle(::Type{V}, ::Type{I}, point_order,
    points) where {V,I}
    local initial_triangle
    i, j, k = point_order[begin], point_order[begin+1], point_order[begin+2]
    initial_triangle = construct_positively_oriented_triangle(V, i, j, k, points)
    i, j, k = indices(initial_triangle)
    p, q, r = get_point(points, i, j, k)
    degenerate_cert = triangle_orientation(p, q, r)
    if length(point_order) > 3 # Do not get stuck in an infinite loop if there are just three points, the three of them being collinear
        while is_degenerate(degenerate_cert)
            circshift!(point_order, -1)
            i, j, k = point_order[begin], point_order[begin+1], point_order[begin+2]
            initial_triangle = construct_positively_oriented_triangle(V, i, j, k, points)
            i, j, k = indices(initial_triangle)
            p, q, r = get_point(points, i, j, k)
            degenerate_cert = triangle_orientation(p, q, r)
        end
    end
    return initial_triangle
end
@inline function get_initial_triangle(tri::Triangulation, point_order)
    V = triangle_type(tri)
    I = integer_type(tri)
    points = get_points(tri)
    return get_initial_triangle(V, I, point_order, points)
end

function initialise_bowyer_watson(points::P;
    IntegerType::Type{I}=Int64,
    EdgeType::Type{E}=NTuple{2,IntegerType},
    TriangleType::Type{V}=NTuple{3,IntegerType},
    EdgesType::Type{Es}=Set{EdgeType},
    TrianglesType::Type{Ts}=Set{TriangleType},
    randomise=true,
    skip_points=Set{IntegerType}(),
    rng::AbstractRNG=Random.default_rng(),
    point_order=get_point_order(points, randomise,
        skip_points, IntegerType,
        rng)) where {P,I,E,V,Es,
    Ts}
    tri = Triangulation(points; IntegerType, EdgeType, TriangleType, EdgesType,
        TrianglesType)
    initial_triangle = get_initial_triangle(tri, point_order) # point_order could get mutated here
    add_triangle!(tri, initial_triangle; update_ghost_edges=true)
    new_representative_point!(tri, I(1))
    u, v, w = indices(initial_triangle)
    p, q, r = get_point(tri, u, v, w)
    for pt in (p, q, r)
        update_centroid_after_addition!(tri, I(1), pt)
    end
    return tri::Triangulation{P,Ts,I,E,Es,Vector{I},Dict{E,Tuple{Vector{I},I}},OrderedDict{I,Vector{I}},
        OrderedDict{I,UnitRange{I}},Dict{I,RepresentativeCoordinates{I,number_type(P)}}}
end

function triangulate_bowyer_watson(points::P;
    IntegerType::Type{I}=Int64,
    EdgeType::Type{E}=NTuple{2,IntegerType},
    TriangleType::Type{V}=NTuple{3,IntegerType},
    EdgesType::Type{Es}=Set{EdgeType},
    TrianglesType::Type{Ts}=Set{TriangleType},
    randomise=true,
    delete_ghosts=true,
    delete_empty_features=true,
    try_last_inserted_point=true,
    skip_points=Set{IntegerType}(),
    num_sample_rule::M=default_num_samples,
    rng::AbstractRNG=Random.default_rng(),
    point_order=get_point_order(points, randomise,
        skip_points, IntegerType,
        rng),
    recompute_representative_point=true) where {P,I,E,V,
    Es,Ts,M}
    tri = initialise_bowyer_watson(points; IntegerType, EdgeType, TriangleType, EdgesType,
        TrianglesType, randomise, skip_points, rng,
        point_order)::Triangulation{P,Ts,I,E,Es,Vector{I},Dict{E,Tuple{Vector{I},I}},
        OrderedDict{I,Vector{I}},
        OrderedDict{I,UnitRange{I}},Dict{I,RepresentativeCoordinates{I,number_type(P)}}}
    _triangulate_bowyer_watson!(tri, point_order, num_sample_rule, delete_ghosts,
        delete_empty_features, try_last_inserted_point, rng,
        recompute_representative_point)
    return tri
end

function _triangulate_bowyer_watson!(tri::Triangulation, point_order,
    num_sample_rule::M=n -> default_num_samples(n),
    delete_ghosts=true, delete_empty_features=true,
    try_last_inserted_point=true,
    rng::AbstractRNG=Random.default_rng(),
    recompute_representative_point=true) where {M}
    remaining_points = @view point_order[(begin+3):end]
    I = integer_type(tri)
    for (num_points, new_point) in enumerate(remaining_points)
        num_currently_inserted = num_points + 3 - 1     # + 3 for the points already inserted
        last_inserted_point_index = point_order[num_currently_inserted]
        currently_inserted_points = @view point_order[begin:num_currently_inserted]
        m = num_sample_rule(num_currently_inserted)
        if try_last_inserted_point
            initial_search_point = I(select_initial_point(get_points(tri), new_point; m,
                point_indices=currently_inserted_points,
                try_points=last_inserted_point_index,
                rng))
        else
            initial_search_point = I(select_initial_point(get_points(tri), new_point; m,
                point_indices=currently_inserted_points,
                rng))
        end
        add_point_bowyer_watson!(tri, new_point, initial_search_point, rng)
    end
    convex_hull!(tri; reconstruct=false)
    recompute_representative_point &&
        compute_representative_points!(tri; use_convex_hull=true)
    delete_ghosts && delete_ghost_triangles!(tri)
    delete_empty_features && clear_empty_features!(tri)
    return nothing
end

function add_point_bowyer_watson!(
    tri::Triangulation, 
    new_point, 
    initial_search_point::I,
    rng::AbstractRNG=Random.default_rng(), 
    update_representative_point=true, 
    store_event_history = Val(false), 
    event_history = nothing) where {I}
    new_point = I(new_point)
    q = get_point(tri, new_point)
    V = jump_and_march(tri, q; m=nothing, point_indices=nothing, try_points=nothing,
        k=initial_search_point, rng, check_existence=Val(has_multiple_segments(tri)))
    flag = point_position_relative_to_triangle(tri, V, q)
    if is_ghost_triangle(V) && is_constrained(tri)
        # When we have a constrained boundary edge, we don't want to walk into its 
        # interior. So let's just check this case now.
        V = rotate_ghost_triangle_to_standard_form(V)
        u, v, w = indices(V)
        if !contains_boundary_edge(tri, v, u)
            add_point_bowyer_watson!(tri, new_point, V, q, flag, update_representative_point, store_event_history, event_history)
        end
    else
        add_point_bowyer_watson!(tri, new_point, V, q, flag, update_representative_point, store_event_history, event_history)
    end
    if is_on(flag) && is_constrained(tri)
        # If the point we are adding appears on a segment, then we perform the depth-first search 
        # on each side the segment. We also need to update the 
        u, v = find_edge(tri, V, new_point)
        if contains_constrained_edge(tri, u, v)
            # First, let us search on the other side of the segment, provide we are not on a boundary edge. 
            w = get_adjacent(tri, v, u)
            T = triangle_type(tri)
            V = construct_triangle(T, v, u, w)
            add_point_bowyer_watson!(tri, new_point, V, q, flag, update_representative_point, store_event_history, event_history)
            # Now, we need to replace the segment by this new segment.
            E = edge_type(tri)
            constrained_edges = get_constrained_edges(tri)
            all_constrained_edges = get_all_constrained_edges(tri)
            for edges in (constrained_edges, all_constrained_edges)
                delete_edge!(edges, construct_edge(E, u, v))
                delete_edge!(edges, construct_edge(E, v, u))
                add_edge!(edges, construct_edge(E, u, new_point))
                add_edge!(edges, construct_edge(E, new_point, v))
                if is_constrained(tri)
                    add_edge!(edges, construct_edge(E, u, new_point))
                    add_edge!(edges, construct_edge(E, new_point, v))
                end
            end
        end
        if contains_boundary_edge(tri, u, v)
            split_boundary_edge!(tri, u, v, new_point)
        elseif contains_boundary_edge(tri, v, u)
            split_boundary_edge!(tri, v, u, new_point)
        end
    end
    return nothing
end

function add_point_bowyer_watson!(
    tri::Triangulation, 
    new_point::I, 
    V, 
    q, 
    flag, 
    update_representative_point=true,
    store_event_history = Val(false),
    event_history = nothing) where {I}
    i, j, k = indices(V)
    ℓ₁ = get_adjacent(tri, j, i)
    ℓ₂ = get_adjacent(tri, k, j)
    ℓ₃ = get_adjacent(tri, i, k)
    delete_triangle!(tri, V; protect_boundary=true, update_ghost_edges=false)
    if is_true(store_event_history)
        delete_triangle!(event_history, V)
    end
    dig_cavity!(tri, new_point, i, j, ℓ₁, flag, V)
    dig_cavity!(tri, new_point, j, k, ℓ₂, flag, V)
    dig_cavity!(tri, new_point, k, i, ℓ₃, flag, V)
    if is_on(flag) && (is_boundary_triangle(tri, V) || is_ghost_triangle(V) && !is_boundary_node(tri, new_point)[1])
        # ^ Need to fix the ghost edges if the point is added onto an existing boundary edge. Note that the last 
        #   condition is in case the ghost edges were already correctly added.
        u, v = find_edge(tri, V, new_point)
        if is_boundary_edge(tri, u, v) || is_boundary_edge(tri, v, u) # If the edge is not itself a boundary edge, no need to worry.
            if !is_boundary_edge(tri, u, v)
                u, v = v, u
            end
            g = get_adjacent(tri, u, v)
            delete_triangle!(tri, v, u, new_point; protect_boundary=true, update_ghost_edges=false)
            delete_triangle!(tri, u, v, g; protect_boundary=true, update_ghost_edges=false)
            add_triangle!(tri, new_point, v, g; update_ghost_edges=false)
            add_triangle!(tri, u, new_point, g; update_ghost_edges=false)
            if is_true(store_event_history)
                delete_triangle!(event_history, v, u, new_point)
                delete_triangle!(event_history, u, v, g)
                add_triangle!(event_history, new_point, v, g)
                add_triangle!(event_history, u, new_point, g)
            end
            if is_constrained(tri) && (contains_boundary_edge(tri, u, v) || contains_boundary_edge(tri, v, u)) # If we don't do this here now, then when we try and do it later we will get a KeyError since we've already modified the boundary edge but we wouldn't have updated the constrained fields
                # We also only do this if contains_boundary_edge since we want to assume that (u, v) does not appear in constrained_edges
                if contains_boundary_edge(tri, u, v)
                    split_boundary_edge!(tri, u, v, new_point)
                elseif contains_boundary_edge(tri, v, u)
                    split_boundary_edge!(tri, v, u, new_point)
                end
                E = edge_type(tri)
                edges = get_all_constrained_edges(tri)
                delete_edge!(edges, construct_edge(E, u, v))
                delete_edge!(edges, construct_edge(E, v, u))
                add_edge!(edges, construct_edge(E, u, new_point))
                add_edge!(edges, construct_edge(E, new_point, v))
                if is_true(store_event_history)
                    add_edge!(event_history, construct_edge(E, u, new_point))
                    add_edge!(event_history, construct_edge(E, new_point, v))
                end
            end
        end
    end
    update_representative_point && update_centroid_after_addition!(tri, I(1), q) # How do we efficiently determine which curve to update for a given q when adding into an existing triangulation?
    return nothing
end

@inline function dig_cavity!(tri::Triangulation, r::I, i, j, ℓ, flag, V) where {I}
    if !edge_exists(ℓ)
        # The triangle has already been deleted in this case. 
        return nothing
    end
    if !contains_constrained_edge(tri, i, j) &&
       is_inside(point_position_relative_to_circumcircle(tri, r, i, j, ℓ)) &&
       !is_boundary_index(ℓ)
        ℓ₁ = get_adjacent(tri, ℓ, i)
        ℓ₂ = get_adjacent(tri, j, ℓ)
        delete_triangle!(tri, j, i, ℓ; protect_boundary=true, update_ghost_edges=false)
        dig_cavity!(tri, r, i, ℓ, ℓ₁, flag, V)
        dig_cavity!(tri, r, ℓ, j, ℓ₂, flag, V)
        if is_true(store_event_history)
            delete_triangle!(event_history, j, i, ℓ)
        end
    else
        # If we are here, then this means that we are on an edge of the polygonal cavity. 
        # Note that this also covers the is_boundary_index(ℓ) case.
        if is_on(flag) && contains_constrained_edge(tri, i, j)
            # When we have a constrained edge (i, j) and we add a point r that lies on the edge, 
            # we can run into an issue where we add a degenerate triangle (i, j, r). We need to 
            # check this. There is probably a much smarter way to do this, but this should only 
            # be done very rarely anyway, so I'm not too concerned about the performance hit here. 
            u, v = find_edge(tri, V, r)
            if u == i && v == j
                return nothing
            else
                add_triangle!(tri, r, i, j; update_ghost_edges=false)
                if is_true(store_event_history)
                    add_triangle!(event_history, r, i, j)
                end
            end
        else
            add_triangle!(tri, r, i, j; update_ghost_edges=false)
            if is_true(store_event_history)
                add_triangle!(event_history, r, i, j)
            end
        end
    end
    return nothing
end
