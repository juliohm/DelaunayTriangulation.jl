"""
    orient_predicate(p, q, r)

Returns `ExactPredicates.orient(p, q, r)`.
"""
orient_predicate(p, q, r) = orient(getxy(p), getxy(q), getxy(r))

"""
    incircle_predicate(a, b, c, p)

Returns `ExactPredicates.incircle(a, b, c, p)`.
"""
incircle_predicate(a, b, c, p) = incircle(getxy(a), getxy(b), getxy(c), getxy(p))

"""
    sameside_predicate(a, b, p)

Returns `ExactPredicates.sameside(p, a, b)` (but we redefine it here).

(The difference in the argument order is to match the convention that the 
main point being tested is the last argument.)
"""
function sameside_predicate(a, b, p)
    _p = getxy(p)
    _a = getxy(a)
    _b = getxy(b)
    if _a < _p && _b < _p || _a > _p && _b > _p
        return 1
    elseif _a < _p && _b > _p || _a > _p && _b < _p
        return -1
    else
        return 0
    end
end

opposite_signs(x, y) = xor(x, y) == -2 # also from ExactPredicates.jl 

"""
    meet_predicate(p, q, a, b) 

Returns `ExactPredicates.meet(p, q, a, b)`  (but we redefine it here).
"""
function meet_predicate(p, q, a, b)
    pqa = orient_predicate(p, q, a)
    pqb = orient_predicate(p, q, b)
    abp = orient_predicate(a, b, p)
    abq = orient_predicate(a, b, q)
    if opposite_signs(pqa, pqb) && opposite_signs(abp, abq)
        return 1
    elseif (pqa ≠ 0 && pqa == pqb) || (abq ≠ 0 && abp == abq)
        return -1
    elseif pqa == 0 && pqb == 0
        if sameside_predicate(a, b, p) == 1 &&
           sameside_predicate(a, b, q) == 1 &&
           sameside_predicate(p, q, a) == 1 &&
           sameside_predicate(p, q, b) == 1
            return -1
        else
            return 0
        end
    else
        return 0
    end
end

"""
    triangle_orientation(p, q, r)

Given a triangle with coordinates `(p, q, r)`, computes its orientation, returning:

- `Certificate.PositivelyOriented`: The triangle is positively oriented.
- `Certificate.Degenerate`: The triangle is degenerate, meaning the coordinates are collinear. 
- `Certificate.NegativelyOriented`: The triangle is negatively oriented.

See also [`orient_predicate`](@ref).
"""
@inline function triangle_orientation(p, q, r)
    cert = orient_predicate(p, q, r)
    return convert_certificate(cert, Cert.NegativelyOriented, Cert.Degenerate,
        Cert.PositivelyOriented)
end

"""
    point_position_relative_to_circle(a, b, c, p)

Given a circle through the coordinates `(a, b, c)`, assumed to be positively oriented, 
computes the position of `p` relative to the circle. In particular, returns:

- `Certificate.Inside`: `p` is inside the circle.
- `Certificate.On`: `p` is on the circle. 
- `Certificate.Outside`: `p` is outside the triangle.

See also [`incircle_predicate`](@ref).
"""
function point_position_relative_to_circle(a, b, c, p)
    cert = incircle_predicate(a, b, c, p)
    return convert_certificate(cert, Cert.Outside, Cert.On, Cert.Inside)
end

"""
    point_position_relative_to_line(a, b, p)

Given a point `p` and the oriented line `(a, b)`, computes the position 
of `p` relative to the line, returning:

- `Certificate.Left`: `p` is to the left of the line. 
- `Certificate.Collinear`: `p` is on the line.
- `Certificate.Right`: `p` is to the right of the line. 

See also [`orient_predicate`](@ref).
"""
function point_position_relative_to_line(a, b, p)
    cert = orient_predicate(a, b, p)
    return convert_certificate(cert, Cert.Right, Cert.Collinear, Cert.Left)
end

"""
    point_position_on_line_segment(a, b, p)

Given a point `p` and the line segment `(a, b)`, assuming `p` 
to be collinear with `a` and `b`, computes the position of `p`
relative to the line segment. In particular, returns:

- `Certificate.On`: `p` is on the line segment, meaning between `a` and `b`.
- `Certificate.Degenerate`: Either `p == a` or `p == b`, i.e. `p` is one of the endpoints. 
- `Certificate.Left`: `p` is off and to the left of the line segment.
- `Certificate.Right`: `p` is off and to the right of the line segment.

See also [`sameside_predicate`](@ref).
"""
function point_position_on_line_segment(a, b, p)
    cert = sameside_predicate(a, b, p)
    converted_cert = convert_certificate(cert, Cert.On, Cert.Degenerate, Cert.Outside)
    if is_outside(converted_cert) # Do we have "a ---- b ---- p" or "p ---- a ---- b"?
        ap_cert = sameside_predicate(a, p, b)
        converted_ap_cert = convert_certificate(ap_cert, Cert.On, Cert.Degenerate,
            Cert.Outside)
        return is_on(converted_ap_cert) ? Cert.Right : Cert.Left
    end
    return converted_cert
end

"""
    line_segment_intersection_type(p, q, a, b)

Given the coordinates `(p, q)` and `(a, b)` defining two line segments, 
tests the number of intersections between the two segments. In particular, 
we return:

- `Certificate.None`: The line segments do not meet at any points. 
- `Certificate.Multiple`: The closed line segments `[p, q]` and `[a, b]` meet in one or several points. 
- `Certificate.Single`: The open line segments `(p, q)` and `(a, b)` meet in a single point. 
- `Certificate.Touching`: One of the endpoints is on `[a, b]`, but there are no other intersections.

See also [`meet_predicate`](@ref).
"""
function line_segment_intersection_type(p, q, a, b)
    cert = meet_predicate(p, q, a, b)
    converted_cert = convert_certificate(cert, Cert.None, Cert.Multiple, Cert.Single)
    if is_multiple(converted_cert)
        #=
        We need to check if the "multiple" really means one endpoint is touching the line, but 
        only one part of it. In particular, we are checking the scenarios (visualising just some of the possibilities):

         p --- a --- b --- q (Multiple)

               b 
               |
               |
         p --- a --- q       (On) 

               p 
               |
               |
         a --- q --- b       (On) 

        To check this, we can check if `(a, b)` is collinear with `p`, but not with `q`, as 
        this implies only a single intersection (if both are collinear, they are on the same 
        line, so there would be multiple). We need to also do the same for `(p, q)`.
        =#
        collinear_cert_1 = point_position_relative_to_line(a, b, p)
        collinear_cert_2 = point_position_relative_to_line(a, b, q)
        if (is_collinear(collinear_cert_1) && !is_collinear(collinear_cert_2)) ||
           (!is_collinear(collinear_cert_1) && is_collinear(collinear_cert_2))
            return Cert.Touching
        end
        collinear_cert_3 = point_position_relative_to_line(p, q, a)
        collinear_cert_4 = point_position_relative_to_line(p, q, b)
        if (is_collinear(collinear_cert_3) && !is_collinear(collinear_cert_4)) ||
           (!is_collinear(collinear_cert_3) && is_collinear(collinear_cert_4))
            return Cert.Touching
        end
    end
    return converted_cert
end

"""
    point_position_relative_to_triangle(a, b, c, p)

Given a positively oriented triangle with coordinates `(a, b, c)`, computes the 
position of `p` relative to the triangle. In particular, returns: 

- `Certificate.Outside`: `p` is outside of the triangle. 
- `Certificate.On`: `p` is on one of the edges. 
- `Certificate.Inside`: `p` is inside the triangle.
"""
function point_position_relative_to_triangle(a, b, c, p)
    edge_ab = point_position_relative_to_line(a, b, p)
    edge_bc = point_position_relative_to_line(b, c, p)
    edge_ca = point_position_relative_to_line(c, a, p)
    all_edge_certs = (edge_ab, edge_bc, edge_ca)
    for (edge_cert, (a, b)) in zip((edge_ab, edge_bc, edge_ca), ((a, b), (b, c), (c, a)))
        if is_collinear(edge_cert) # Just being collinear isn't enough - what if it's collinear but off the edge?
            cert = point_position_on_line_segment(a, b, p)
            if is_left(cert) || is_right(cert)
                return Cert.Outside
            else
                return Cert.On
            end
        end
    end
    all(is_left, all_edge_certs) && return Cert.Inside
    return Cert.Outside
end

"""
    point_position_relative_to_oriented_outer_halfplane(a, b, p)

Given an edge with coordinates `(a, b)` and a point `p`, 
tests the position of `p` relative to the oriented outer halfplane defined 
by `(a, b)`. The oriented outer halfplane is the union of the open halfplane 
defined by the region to the left of the oriented line `(a, b)`, and the 
open line segment `(a, b)`. The returned values are:

- `Cert.Outside`: `p` is outside of the oriented outer halfplane, meaning to the right of the line `(a, b)` or collinear with `a` and `b` but not on the line segment `(a, b)`.
- `Cert.On`: `p` is on the open line segment `(a, b)`.
- `Cert.Inside`: `p` is inside of the oriented outer halfplane, meaning to the left of the line `(a, b)`.
"""
function point_position_relative_to_oriented_outer_halfplane(a, b, p)
    in_open_halfplane = point_position_relative_to_line(a, b, p)
    if is_collinear(in_open_halfplane)
        is_on_boundary_edge = point_position_on_line_segment(a, b, p)
        if is_on(is_on_boundary_edge)
            return Cert.On
        else
            return Cert.Outside
        end
    elseif is_left(in_open_halfplane)
        return Cert.Inside
    else
        return Cert.Outside
    end
end

"""
    is_legal(p, q, r, s)

Given an edge `pq`, incident to two triangles `pqr` and `qps`, tests 
if the edge `pq` is legal, i.e. if `s` is not inside the triangle through 
`p`, `q`, and `r`.
"""
function is_legal(p, q, r, s)
    incirc = point_position_relative_to_circle(p, q, r, s)
    if is_inside(incirc)
        return Cert.Illegal
    else
        return Cert.Legal
    end
end

# this is probably slower than it needs to be, but it's only used in tests so it's fine
"""
    triangle_line_segment_intersection(p, q, r, a, b)

Given a triangle `(p, q, r)` and a line segment `(a, b)`,
tests if `(a, b)` intersects the triangle's interior. Returns:

- `Cert.Inside`: `(a, b)` is entirely inside `(p, q, r)`.
- `Cert.Single`: `(a, b)` has one endpoint inside `(p, q, r)`, and the other is outside.
- `Cert.Outside`: `(a, b)` is entirely outside `(p, q, r)`.
- `Cert.Touching`: `(a, b)` is on `(p, q, r)`'s boundary, but not in its interior.
- `Cert.Multiple`: `(a, b)` passes entirely through `(p, q, r)`. This includes the case where a point is on the boundary of `(p, q, r)`.
"""
function triangle_line_segment_intersection(p, q, r, a, b)
    ## Break into cases:
    # Case I: (a, b) is an edge of (p, q, r)
    a_eq = any(==(a), (p, q, r))
    b_eq = any(==(b), (p, q, r))
    if a_eq && b_eq
        return Cert.Touching
    end

    # Case II: a or b is one of the vertices of (p, q, r)
    if a_eq || b_eq
        a, b = a_eq ? (a, b) : (b, a) # rotate so that a is one of the vertices 
        p, q, r = choose_uvw(a == p, a == q, a == r, p, q, r) # rotate so that a == p
        # First, find position of b relative to the edges pq and pr 
        pqb = point_position_relative_to_line(p, q, b)
        prb = point_position_relative_to_line(p, r, b)
        if is_right(pqb) || is_left(prb)
            # If b is right of pq or left of pr, it is away from the interior and thus outside
            return Cert.Outside
        elseif is_collinear(pqb) || is_collinear(prb)
            # If b is collinear with an edge, it could be on the edge or away from it
            s = is_collinear(pqb) ? q : r
            b_pos = point_position_on_line_segment(p, s, b)
            return is_left(b_pos) ? Cert.Outside : Cert.Touching
        else
            # If we are here, it means that b is between the rays through pq and pr. 
            # We just need to determine if b is inside or the triangle or outside. 
            # See that if b is inside, then it is left of qr, but if it is outside 
            # then it is right of qr. 
            qrb = point_position_relative_to_line(q, r, b)
            if is_right(qrb)
                return Cert.Multiple # Technically, one could call this Single, but Multiple is the most appropriate
            else
                return Cert.Inside # Also covers the is_on(qrb) case 
            end
        end
    end

    # We have now covered the cases where a or b, or both, are a vertex of (p, q, r).
    # The remaining degenerate case is the case where a or b, or both, are on an edge 
    # of (p, q, r). We can determine this possibility with the following certificates.
    a_tri = point_position_relative_to_triangle(p, q, r, a)
    b_tri = point_position_relative_to_triangle(p, q, r, b)

    # Case III: a and b are both on an edge of (p, q, r)
    if is_on(a_tri) && is_on(b_tri)
        # There are two options here, either a and b are both on the same edge,
        # or they are on different edges. In the latter case, (a, b) is entirely in 
        # (p, q, r). To determine this case, we just test against each edge.
        pqa = is_collinear(point_position_relative_to_line(p, q, a))
        qra = pqa ? false : is_collinear(point_position_relative_to_line(q, r, a)) # skip computation if we already know a result
        #rpa = (pqa || qra) ? false : is_collinear(point_position_relative_to_line(r, p, a))
        pqb = is_collinear(point_position_relative_to_line(p, q, b))
        qrb = pqb ? false : is_collinear(point_position_relative_to_line(q, r, b))
        #rpb = (pqb || qrb) ? false : is_collinear(point_position_relative_to_line(r, p, b))
        # Don't need rpa or rpb above, since checking the two edges automatically implies the result for the third edge
        a_edge = pqa ? (p, q) : (qra ? (q, r) : (r, p))
        b_edge = pqb ? (p, q) : (qrb ? (q, r) : (r, p))
        return a_edge == b_edge ? Cert.Touching : Cert.Inside
    end

    # Case IV: a or b are on an edge of (p, q, r)
    # For this case, the working is essentially the same as in Case II.
    if is_on(a_tri) || is_on(b_tri)
        # Rotate so that a is on (p, q)
        a, b = is_on(a_tri) ? (a, b) : (b, a)
        pqa = is_collinear(point_position_relative_to_line(p, q, a))
        qra = pqa ? false : is_collinear(point_position_relative_to_line(q, r, a))
        rpa = !(pqa || qra)
        p, q, r = choose_uvw(pqa, qra, rpa, p, q, r)
        # Similar to Case II, we start by considering the position of b relative to pq and qr 
        prb = point_position_relative_to_line(p, r, b)
        qrb = point_position_relative_to_line(q, r, b)
        # First, if we are left of right of pr or qr, respectively, we must have exited the triangle
        if is_left(prb) || is_right(qrb)
            return Cert.Multiple
        end
        # It is also possible that b is collinear with pq 
        pqb = point_position_relative_to_line(p, q, b)
        if is_collinear(pqb)
            #b_pos = point_position_on_line_segment(p, q, b)
            # We don't really need to know the position, we already know now that ab touches the triangle. 
            return Cert.Touching
            # Alternatively, b might be away from pq, meaning it is outside:
        elseif is_right(pqb)
            return Cert.Outside
        else
            # We now know that b is left of pqb, which from the above must imply that b is in the triangle. 
            return Cert.Inside
        end
    end

    # We can now assume that neither a nor b appear anywhere on (p, q, r). Just to make things a bit simpler, 
    # let us determine directly where a and b are relative to the triangle 
    a_pos = point_position_relative_to_triangle(p, q, r, a)
    b_pos = point_position_relative_to_triangle(p, q, r, b)

    # Case V: a and b are inside the triangle 
    if is_inside(a_pos) && is_inside(b_pos)
        return Cert.Inside
    elseif is_inside(a_pos) || is_inside(b_pos)
        # Case VI: Only one of a and b are inside the triangle 
        return Cert.Single
    else # is_outside(a_pos) && is_outside(b_pos)
        # Case VII: Both a and b are outside the triangle 
        # We consider the intersection of ab with each edge 
        pq_ab = line_segment_intersection_type(p, q, a, b)
        qr_ab = line_segment_intersection_type(q, r, a, b)
        rp_ab = line_segment_intersection_type(r, p, a, b)
        num_none = count(is_none, (pq_ab, qr_ab, rp_ab))
        num_touching = count(is_touching, (pq_ab, qr_ab, rp_ab))
        num_multiple = count(is_multiple, (pq_ab, qr_ab, rp_ab))
        # The possible cases:
        #   1. There are no intersections with any edge: num_none == 3
        #   2. ab only touches a single edge with an endpoint, but doesn't go through it. Fortunately, we tested for this case already. 
        #   3. It is possible that ab does not touch an edge with an endpoint, but its interior touches one of the points of the triangle, but doesn't go inside the triangle: num_touching == 2
        #   4. Another case is that ab is completely collinear with an edge. This happens when num_multiple == 1. This case is hard to distinguish from 3, so to handle it we need to do some more orientation tests.
        #   5. In all other cases, ab goes through the triangle and out the other side
        if num_none == 3 
            return Cert.Outside 
        elseif num_multiple == 1 || num_touching == 2 
            # This is for cases 3 or 4 above. We need to see how ab line up with the vertices of (p, q, r)
            abp = point_position_relative_to_line(a, b, p)
            abq = point_position_relative_to_line(a, b, q)
            abr = point_position_relative_to_line(a, b, r)
            if count(is_collinear, (abp, abq, abr)) == 2
                return Cert.Touching # lines up with an edge 
            else 
                return Cert.Outside # interior only just touches a single vertex 
            end
        else
            return Cert.Multiple 
        end
    end
end