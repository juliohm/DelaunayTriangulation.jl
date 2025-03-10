```@meta
CurrentModule = DelaunayTriangulation
```

## Application: Counting Function Calls

The ability to customise the primitive interfaces completely has many advantages. In the previous section we gave a complete example for how to setup and define all the functions required. Here, we will show an actual example where customisation can be really useful.

The application in mind is to study how many times a function is being called during the construction of a triangulation. By defining custom definitions for points and triangles, we can estimate how many times we compute predicates and how many times we add and remove triangles. 

### Setting Up

To start the application, we first load in the packages.

```julia
using DelaunayTriangulation
using CairoMakie
using StatsBase
const DT = DelaunayTriangulation
```

We then need to define the custom primitves and the required definitions. First, the structs and basic definitions:

```julia
struct CustomPoint
    x::Float64
    y::Float64
end
struct CustomTriangle
    i::Int
    j::Int
    k::Int
end
DT.getx(p::CustomPoint) = p.x
DT.gety(p::CustomPoint) = p.y
DT.number_type(::Type{CustomPoint}) = Float64
DT.construct_triangle(::Type{CustomTriangle}, i, j, k) = CustomTriangle(i, j, k)
DT.geti(tri::CustomTriangle) = tri.i
DT.getj(tri::CustomTriangle) = tri.j
DT.getk(tri::CustomTriangle) = tri.k
DT.integer_type(::Type{CustomTriangle}) = Int32
DT.getpoint(pts::Vector{CustomPoint}, i::Int) = pts[i]
```

Next, we define the actual counter. This will be a mutable struct.

```julia
mutable struct AlgorithmStats
    orient_calls::Int
    incircle_calls::Int
    parallelorder_calls::Int
    sameside_calls::Int
    meet_calls::Int
    added_triangles::Int
    deleted_triangles::Int
end
AlgorithmStats() = AlgorithmStats(0, 0, 0, 0, 0, 0, 0)
AlgorithmStats(opstats::AlgorithmStats) = AlgorithmStats(opstats.orient_calls, opstats.incircle_calls, opstats.parallelorder_calls, opstats.sameside_calls, opstats.meet_calls, opstats.added_triangles, opstats.deleted_triangles)
nt = Base.Threads.nthreads()
const opstats = [AlgorithmStats() for _ in 1:nt]
reset_opstats!(id=Base.Threads.threadid()) = (opstats[id] = AlgorithmStats())
```

The constant `opstats` is a vector of counters so that we can use multithreading. The methods we need to overwrite for this counter are:

```julia
function DT.add_to_triangles!(tri::Set{CustomTriangle}, triangle::CustomTriangle)
    push!(tri, triangle)
    opstats[Base.Threads.threadid()].added_triangles += 1
    return nothing
end
function DT.delete_from_triangles!(tri::Set{CustomTriangle}, triangle::CustomTriangle)
    delete!(tri, triangle)
    opstats[Base.Threads.threadid()].deleted_triangles += 1
    return nothing
end
function DT.orient_predicate(p::CustomPoint, q::CustomPoint, r::CustomPoint)
    o = DT.orient_predicate(getxy(p), getxy(q), getxy(r))
    opstats[Base.Threads.threadid()].orient_calls += 1
    return o
end
function DT.incircle_predicate(p::CustomPoint, q::CustomPoint, r::CustomPoint, s::CustomPoint)
    o = DT.incircle_predicate(getxy(p), getxy(q), getxy(r), getxy(s))
    opstats[Base.Threads.threadid()].incircle_calls += 1
    return o
end
function DT.parallelorder_predicate(p::CustomPoint, q::CustomPoint, r::CustomPoint, s::CustomPoint)
    o = DT.parallelorder_predicate(getxy(p), getxy(q), getxy(r), getxy(s))
    opstats[Base.Threads.threadid()].parallelorder_calls += 1
    return o
end
function DT.sameside_predicate(p::CustomPoint, q::CustomPoint, r::CustomPoint)
    o = DT.sameside_predicate(getxy(p), getxy(q), getxy(r))
    opstats[Base.Threads.threadid()].sameside_calls += 1
    return o
end
function DT.meet_predicate(p::CustomPoint, q::CustomPoint, r::CustomPoint, s::CustomPoint)
    o = DT.meet_predicate(getxy(p), getxy(q), getxy(r), getxy(s))
    opstats[Base.Threads.threadid()].meet_calls += 1
    return o
end
```

Next, let's define the functions for summarising the simulations we'll perform, the simulation functions themselves, and a function for plotting results.

```julia
## Summary functions 
struct AlgorithmStatsSummary
    orient_calls::NTuple{2,Float64}
    incircle_calls::NTuple{2,Float64}
    parallelorder_calls::NTuple{2,Float64}
    sameside_calls::NTuple{2,Float64}
    meet_calls::NTuple{2,Float64}
    added_triangles::NTuple{2,Float64}
    deleted_triangles::NTuple{2,Float64}
    function AlgorithmStatsSummary(sims::Vector{AlgorithmStats})
        orient_calls = quantile([sim.orient_calls for sim in sims], (0.025, 0.975))
        incircle_calls = quantile([sim.incircle_calls for sim in sims], (0.025, 0.975))
        parallelorder_calls = quantile([sim.parallelorder_calls for sim in sims], (0.025, 0.975))
        sameside_calls = quantile([sim.sameside_calls for sim in sims], (0.025, 0.975))
        meet_calls = quantile([sim.meet_calls for sim in sims], (0.025, 0.975))
        added_triangles = quantile([sim.added_triangles for sim in sims], (0.025, 0.975))
        deleted_triangles = quantile([sim.deleted_triangles for sim in sims], (0.025, 0.975))
        return new(orient_calls, incircle_calls, parallelorder_calls, sameside_calls, meet_calls, added_triangles, deleted_triangles)
    end
end
summarise_simulations(sims) = AlgorithmStatsSummary(sims)

## Point generators 
function generate_random_points(npts)
    pts = [CustomPoint(rand(), rand()) for _ in 1:npts]
    return pts
end
function generate_structured_points(npts)
    nx = isqrt(npts)
    ny = isqrt(npts)
    points = CustomPoint[]
    for i in 1:nx
        for j in 1:ny
            x = (i - 1) / (nx - 1)
            y = (j - 1) / (ny - 1)
            push!(points, CustomPoint(x, y))
        end
    end
    while length(points) < npts
        push!(points, CustomPoint(rand(), rand()))
    end
    return points
end

## Simulation functions
function simulate(npts; f=generate_random_points, edges=nothing)
    reset_opstats!()
    if f isa Function
    pts = f(npts)
    else 
        pts=f # later, when we look at constrained triangulations, we'll pass points and edges but not f as a function 
    end
    triangulate(pts; TriangleType=CustomTriangle, edges=edges)
    return AlgorithmStats(opstats[Base.Threads.threadid()])
end
function simulate(npts, nsims; f=generate_random_points, edges=nothing)
    sim_results = Vector{AlgorithmStats}(undef, nsims)
    for i in 1:nsims
        sim_results[i] = simulate(npts; f, edges)
    end
    return sim_results, summarise_simulations(sim_results)
end
function simulate(npts::AbstractVector{Int}, nsims; f=generate_random_points, edges=nothing)
    sim_results = Vector{Tuple{Vector{AlgorithmStats},AlgorithmStatsSummary}}(undef, length(npts))
    Base.Threads.@threads :static for i in eachindex(npts)
        n = npts[i]
        sim_results[i] = simulate(n, nsims; f, edges)
    end
    return first.(sim_results), last.(sim_results)
end

## Complete plotting function
const alp = join('a':'z')
function plot_fnc!(fig, i, j, statistic, title, simulation_results, simulation_summaries, npts, dolog=false)
    scale = dolog ? log10 : identity
    ax = Axis(fig[i, j], xlabel=L"n", ylabel=L"$ $Number", title=title, titlealign=:left, width=600, height=300, xscale=scale, yscale=scale)
    scatters = NTuple{2,Int}[]
    lower = Vector{Float64}(undef, length(npts))
    upper = Vector{Float64}(undef, length(npts))
    for (k, n) in enumerate(npts)
        for sim in simulation_results[k]
            push!(scatters, (n, getfield(sim, statistic)))
        end
        result = getfield(simulation_summaries[k], statistic)
        lower[k] = result[1]
        upper[k] = result[2]
    end
    scatter!(ax, scatters, color=:black, markersize=3)
    band!(ax, npts, lower, upper, color=(:blue, 0.2), strokewidth=2)
end
function plot_fnc(npts, simulation_results, simulation_summaries)
    fig = Figure(fontsize=36)
    dolog = (true, false, false, false, false, false, false)
    for (k, (f, dolog)) in enumerate(zip(fieldnames(AlgorithmStats), dolog))
        title = L"(%$(alp[k])):$ $ %$(f)"
        i, j = ceil(Int, k / 4), mod1(k, 4)
        plot_fnc!(fig, i, j, f, title, simulation_results, simulation_summaries, npts, dolog)
    end
    resize_to_layout!(fig)
    fig
end

## Analysis functions for constrained triangulations: We'll fix the number of points and vary the number of edges 
function get_random_vertices_and_constrained_edges(nverts1, nverts2, nedges, f)
    ## To generate a random set of constrained edges, we get a random small triangulation, 
    ## and we just take the edges from that triangulation.
    points = f(nverts1)
    tri = triangulate(points)
    edges = Set{NTuple{2,Int}}()
    all_edges = collect(each_solid_edge(tri))
    iter = 0
    while length(edges) < nedges && iter < 10000
        S = DT.random_edge(all_edges)
        push!(edges, S)
        iter += 1
    end
    ## Now get the rest of the points 
    while length(points) < nverts2
        push!(points, CustomPoint(rand(), rand()))
    end
    return points, edges
end
function simulate_cdt(ne::AbstractVector{Int}, nsims; f=generate_random_points)
    sim_results = Vector{Tuple{Vector{AlgorithmStats},AlgorithmStatsSummary}}(undef, length(ne))
    Base.Threads.@threads :static for i in eachindex(ne)
        points, edges = get_random_vertices_and_constrained_edges(500, 2000, ne[i], f)
        sim_results[i] = simulate(ne[i], nsims; f=points, edges)
    end
    return first.(sim_results), last.(sim_results)
end
```

### The Analysis 

Now let's do the actual analysis and show the actual figures. For this analysis, we compare the results when using randomly distributed points, and when using point sets with many collinearities. It would be interesting to revisit these results when we later have methods for spatial sorting ([#34](https://github.com/DanielVandH/DelaunayTriangulation.jl/issues/34)).

First, let's look at the unconstrained triangulations.

```julia
npts = [ceil(Int, 10^x) for x in LinRange(1, 4, 250)] |> unique
nsims = 10
simulation_results_random, simulation_summaries_random = simulate(npts, nsims; f=generate_random_points)
simulation_results_structured, simulation_summaries_structured = simulate(npts, nsims; f=generate_structured_points)

fig_random = plot_fnc(npts, simulation_results_random, simulation_summaries_random)
fig_structured = plot_fnc(npts, simulation_results_structured, simulation_summaries_structured)
```

```@raw html
<figure>
    <img src='../figs/random.png', alt='Counting random unconstrained triangulation function calls'><br>
</figure>
```

```@raw html
<figure>
    <img src='../figs/structured.png', alt='Counting structured unconstrained triangulation function calls'><br>
</figure>
```

Of course, `parallelorder_predicate` is not called at any time as it is only used for computing constrained triangulations. We see that the number of `orient_predicate` calls grows exponentially with the number of points (note the log scales in (a)). The number of `incircle_calls` appears linear in `n`, as do the number of added and deleted triangles (which is probably clear from Euler's formula). Moreover, we see that there are no `sameside_calls` for the random point sets, but when we introduce many collinearities we have to spend a lot of time calling `sameside_calls` to resolve collinearities in the point location steps. The number of `meet_calls` is pretty similar between the two point set types, although we use call it more often in the structured case. (`meet_predicate` is used when classifying the type of an intersection when we start the point location step at a point on the boundary, allowing us to distinguish correctly between the exterior and the interior of the domain, and also between the boundary of the domain itself in the structured case.)

Next, here are the results for the constrained triangulations, keeping the number of points fixed at $2,000$ and varying the number of edges (no boundary nodes).

```julia
ne = [ceil(Int, 10^x) for x in LinRange(0.3, 3, 270)] |> unique
simulation_results_random_cdt, simulation_summaries_random_cdt = simulate_cdt(ne, nsims; f=generate_random_points)
simulation_results_structured_cdt, simulation_summaries_structured_cdt = simulate_cdt(ne, nsims; f=generate_structured_points)

fig_random_cdt = plot_fnc(ne, simulation_results_random_cdt, simulation_summaries_random_cdt)
fig_structured_cdt = plot_fnc(ne, simulation_results_structured_cdt, simulation_summaries_structured_cdt)
```

```@raw html
<figure>
    <img src='../figs/random_cdt.png', alt='Counting random constrained triangulation function calls'><br>
</figure>
```

```@raw html
<figure>
    <img src='../figs/structured_cdt.png', alt='Counting structured constrained triangulation function calls'><br>
</figure>
```

Remember that, in these plots, $n$ is the number of edges. The results are pretty similar in this case. The number of `orient` calls is now linear in the number of constrained edges, despite it being exponential in the number of points. The other new result is `parallelorder` is called very few times, also being roughly linear in $n$.
