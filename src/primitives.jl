############################################
##
## ABSTRACT PRIMITIVES 
##
############################################
"""
    abstract type AbstractEdge{I} end

Abstract type representing an edge with indices of type `I`. 
Typically an `NTuple{2, Int64}`. Edges are iterable, writing 

- `i, j = e`,

which returns `(initial(e), terminal(e))`. Note that we define `length(e::AbstractEdge) = 2`.

`AbstractEdges` must have methods for

- `initial(e)`: The start of the edge.
- `terminal(e)`: The end of the edge.

`AbstractEdge`s must also have a method for constucting from a function call, i.e. if `E::AbstractEdge{I}`,
then `E(i, j)` should construct an edge of that type.

If you are defining a new edge that has mutable containers, you would encounter issues 
with accessing dictionaries. The solution to this is to either switch to an immutable container, 
or define new methods for `==` and `hash`. We define these two new methods below to avoid this 
issue. See https://stackoverflow.com/a/31460387 for a discussion on this. The new methods we 
define say that two edges are equal if `(initial(e), terminal(e))` is the same `Tuple` for 
both edges, and `hash(e::AbstractEdge, h::UInt) = hash(initial(e), hash(terminal(e), h))`.
"""
abstract type AbstractEdge{I} end
function Base.iterate(e::AbstractEdge, state=1)
    if state == 1
        return (initial(e), state + 1)
    elseif state == 2
        return (terminal(e), state + 1)
    else
        return nothing
    end
end
Base.eltype(::AbstractEdge{I}) where {I} = I
Base.eltype(::Type{AbstractEdge{I}}) where {I} = I
Base.length(e::AbstractEdge) = 2
Base.:(==)(pq::AbstractEdge, rs::AbstractEdge) = initial(pq) == initial(rs) && terminal(pq) == terminal(rs) 
Base.hash(pq::AbstractEdge, h::UInt) = hash(initial(pq), hash(terminal(pq), h))

"""
    abstract type AbstractTriangle{I} end

Abstract type representing a triangle with indices of type `I`. 
Typically an `NTuple{3, Int64}`.

`AbstractTriangle`s must have methods for:
- `geti(T)`: The first vertex.
- `getj(T)`: The second vertex. 
- `getk(T)`: The third vertex. 

`AbstractTriangle`s must also have a method for constucting from a function call, i.e. 
if `V::AbstractTriangle{I}`, then `V(i, j, k)` should construct a triangle of that type
with indices `(i, j, k)`. A similar method is also needed for `NTuple{3, I}`, i.e. 
`V((i, j, k))` must give the same result as `V(i, j, k)`.

Circular shifts of a triangle's indices can be obtained via 

- `shift_triangle_0(T) = (geti(T), getj(T), getk(T))`.
- `shift_triangle_1(T) = (getj(T), getk(T), geti(T))`.
- `shift_triangle_2(T) = (getk(T), geti(T), getj(T))`.

Circular shifts of the triangle itself can be obtained via 

- `shift_triangle_0(T::V) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices_0(T))`
- `shift_triangle_1(T::V) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices_1(T))`
- `shift_triangle_2(T::V) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices_2(T))`

See also [`shift_triangle_indices`](@ref) and [`shift_triangle`](@ref).

Triangles are iterable, writing 

- `i, j, k = T`

will return `(geti(T), getj(T), getk(T))`. Note that we define `length(T::AbstractTriangle) = 3`.

Triangles are equal if their nidices are equal (up to a circular shift).
"""
abstract type AbstractTriangle{I} end
indices(T::AbstractTriangle) = (geti(T), getj(T), getk(T))
shift_triangle_indices_0(T::AbstractTriangle) = (geti(T), getj(T), getk(T))
shift_triangle_indices_1(T::AbstractTriangle) = (getj(T), getk(T), geti(T))
shift_triangle_indices_2(T::AbstractTriangle) = (getk(T), geti(T), getj(T))
shift_triangle_0(T::V) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices_0(T))
shift_triangle_1(T::V) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices_1(T))
shift_triangle_2(T::V) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices_2(T))
shift_triangle_indices(T, m) = m == 0 ? shift_triangle_indices_0(T) : (m == 1 ? shift_triangle_indices_1(T) : shift_triangle_indices_2(T))
shift_triangle(T::V, m) where {I,V<:AbstractTriangle{I}} = V(shift_triangle_indices(T, m))
function Base.iterate(T::AbstractTriangle, state=1)
    if state == 1
        return (geti(T), state + 1)
    elseif state == 2
        return (getj(T), state + 1)
    elseif state == 3
        return (getk(T), state + 1)
    else
        return nothing
    end
end
Base.eltype(::AbstractTriangle{I}) where {I} = I
Base.eltype(::Type{AbstractTriangle{I}}) where {I} = I
Base.length(T::AbstractTriangle) = 3
function Base.:(==)(T::AbstractTriangle, V::AbstractTriangle)
    return indices(T) == indices(V) ||
           shift_triangle_indices_1(T) == indices(V) ||
           shift_triangle_indices_2(T) == indices(V)
end

"""
    abstract type AbstractPoint{T, A} end 

Abstract type representing a point with element type `T` stored in a container of 
type `A`. Typically a `Vector{Float64}` or `SVector{2, Float64}`.

`AbstractPoint`s must have methods for:
- `getx(p)`: Get the `x`-coordinate of the point.
- `gety(p)`: Get the `y`-coordinate of the point.

`AbstractPoint`s must also have a method for constucting from a function call, i.e. 
if `P::AbstractPoint{T, A}`, then `P(x, y)` should construct a point of that type
with coordinates `(x, y)`. Similarly, `P((x, y))` must give the same result as `P(x, y)`.

Note that for compatibility with ExactPredicates.jl, whenever `T ≠ Float64` the function 
`Tuple` is defined to return `(Float64(getx(p)), Float64(gety(p)))` rather than 
`(T(getx(p)), T(gety(p))`, as exact predicates are not currently available 
for non-`Float64` types. (This means that `T` is not really used anywhere, 
but to make it easier in the future in case we can use it in other places we 
explicitly support it.)) If you really do want to use predicates with a 
custom `T`, you will need to redefine the methods 

- `ExactPredicates.orient(p::AbstractPoint, q::AbstractPoint, r::AbstractPoint)`
- `ExactPredicates.incircle(p::AbstractPoint, q::AbstractPoint, r::AbstractPoint, s::AbstractPoint)`

for your new type; just note that the resulting predicates will no longer be guaranteed. (Our 
conversion from `T` to `Float64` may not also be exact anyway, note.)

Points are iterable, writing 

- `x, y = p`

gives `x = getx(p)` and `y = gety(p)`. Note that we define `length(p) = 2`.
"""
abstract type AbstractPoint{T,A} end
Base.Tuple(p::AbstractPoint{Float64,A}) where {A} = (getx(p), gety(p))
Base.Tuple(p::AbstractPoint) = (Float64(getx(p)), Float64(gety(p)))
function Base.iterate(p::AbstractPoint, state=1)
    if state == 1
        return (getx(p), state + 1)
    elseif state == 2
        return (gety(p), state + 1)
        return nothing
    end
end
Base.eltype(::AbstractPoint{T,A}) where {T,A} = T
Base.eltype(::Type{AbstractPoint{T,A}}) where {T,A} = T
Base.length(p::AbstractPoint) = 2
(::Type{P})(p::P) where {P<:AbstractPoint} = p

############################################
##
## SPECIFIC DATA TYPES 
##
############################################
"""
    struct Edge{I} <: AbstractEdge{I}

A data structure for an edge, with fields

- `initial::I`: The initial point of the edge. Can be accessed via `initial(e::Edge)`.
- `terminal::I`: The terminal point of the edge. Can be accessed via `terminal(e::Edge)`.
"""
struct Edge{I} <: AbstractEdge{I}
    initial::I
    terminal::I
    Edge(i::I, j::I) where {I} = new{I}(i, j)
    Edge(ij::NTuple{2,I}) where {I} = new{I}(ij[1], ij[2])
    Edge{I}(i, j) where {I} = new{I}(convert(I, i), convert(I, j))
end
initial(e::Edge) = e.initial
terminal(e::Edge) = e.terminal

"""
    struct Triangle{I} <: AbstractTriangle{I}

A triangle data structure, with field

- `indices::NTuple{3, I}`: The indices of the triangle's vertices, accessed via `indices`.

The individual indices can be accessed via `geti`, `getj`, and `getk`.
"""
struct Triangle{I} <: AbstractTriangle{I}
    indices::NTuple{3,I}
    Triangle(indices::NTuple{3,I}) where {I} = new{I}(indices)
    Triangle(i::I, j::I, k::I) where {I} = new{I}((i, j, k))
    Triangle{I}(indices) where {I} = new{I}(indices)
    Triangle{I}(i, j, k) where {I} = Triangle(convert(I, i), convert(I, j), convert(I, k))
end
geti(T::Triangle) = T.indices[1]
getj(T::Triangle) = T.indices[2]
getk(T::Triangle) = T.indices[3]

"""
    struct Point{T,A} <: AbstractPoint{T,A}

A data structure for a point, with field

- `coords::A`: The coordinates of the point, accessed via `coords`.

The individual coordinates can be expressed via `getx` and `gety`.
"""
struct Point{T,A} <: AbstractPoint{T,A}
    coords::A
    Point(x::T, y::T) where {T} = new{T,Vector{T}}(T[x, y])
    Point{A}(x, y) where {A} = new{eltype(A),A}(convert(A, eltype(A)[x, y]))
    Point(coords::A) where {A} = new{eltype(coords),A}(coords)
    Point(p::P) where {P<:Point} = p
    Point{T,A}(x, y) where {T,A} = new{T,A}(A(collect((x, y))))
end
coords(p::Point) = p.coords
getx(p::Point) = first(coords(p))
gety(p::Point) = last(coords(p))
Base.:(==)(p::Point, q::Point) = isequal(getx(p), getx(q)) && isequal(gety(p), gety(q))
