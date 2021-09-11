"""
   Partial(dist)

Creates the `Partial{dist}` distance.

`Partial{dist}`  returns the  minimum distance  between the shorter string and substrings of the longer string that have a length equal to the shorter string.

See http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/

### Examples
```julia-repl
julia> s1 = "New York Mets vs Atlanta Braves"
julia> s2 = "Atlanta Braves vs New York Mets"
julia> Partial(RatcliffObershelp())(s1, s2)
0.5483870967741935
```
"""
struct Partial{S <: SemiMetric} <: SemiMetric
    dist::S
end

function (dist::Partial)(s1, s2)
    (s1 === missing) | (s2 === missing) && return missing
    s1, s2 = reorder(s1, s2)
    len1, len2 = length(s1), length(s2)
    out = dist.dist(s1, s2)
    ((len1 == 0) | (len1 == len2)) && return out
    for x in qgrams(s2, len1)
        curr = dist.dist(s1, x)
        out = min(out, curr)
    end
    return out
end

function (dist::Partial{RatcliffObershelp})(s1, s2)
    (s1 === missing) | (s2 === missing) && return missing
    len1, len2 = length(s1), length(s2)
    len1 == len2 && return dist.dist(s1, s2)
    out = 1.0
    for r in matching_blocks(s1, s2, 1, 1, len1, len2)
        # Make sure the substring of s2 has length len1
        s2_start = r[2] - r[1] + 1
        s2_end = s2_start + len1 - 1
        if s2_start < 1
            s2_end += 1 - s2_start
            s2_start += 1 - s2_start
        elseif s2_end > len2
            s2_start += len2 - s2_end
            s2_end += len2 - s2_end
        end
        n_matched = length_matching_blocks(s1, s2, 1, s2_start, len1, s2_end)
        curr = 1 - 2 * n_matched / (len1 + s2_end - s2_start + 1)
        out = min(out, curr)
    end
    return out
end

function matching_blocks(s1, s2, start1::Integer, start2::Integer, end1::Integer, end2::Integer)
    x = Set{Tuple{Int, Int, Int}}()
    p = zeros(Int, max(end1 - start1, end2 - start2) + 1)
    matching_blocks!(x, p, s1, s2, start1, start2, end1, end2)
end

function matching_blocks!(x::Set{Tuple{Int, Int, Int}}, p::Vector{Int}, s1, s2, start1::Integer, start2::Integer, end1::Integer, end2::Integer)
    j1, j2, len = longest_common_pattern!(p, s1, s2, start1, start2, end1, end2)
    # exit if there is no common substring
    len == 0 && return x
    # add the info of the common to the existing set
    push!(x, (j1, j2, len))
     # add the longest common substring that happens before
    matching_blocks!(x, p, s1, s2, start1, start2, j1 - 1, j2 - 1)
     # add the longest common substring that happens after
    matching_blocks!(x, p, s1, s2, j1 + len, j2 + len, end1, end2)
    return x
end

function normalize(dist::Partial; max_dist = 1.0)
    Partial(normalize(dist.dist; max_dist = max_dist))
end

"""
   TokenSort(dist)

Creates the `TokenSort{dist}` distance.

`TokenSort{dist}` returns the distance between strings after reording words alphabetically.
See http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/

It is only defined on AbstractStrings.

### Examples
```julia-repl
julia> s1 = "New York Mets vs Atlanta Braves"
julia> s1 = "New York Mets vs Atlanta Braves"
julia> s2 = "Atlanta Braves vs New York Mets"
julia> TokenSort(RatcliffObershelp())(s1, s2)
0.0
```
"""
struct TokenSort{S <: SemiMetric} <: SemiMetric
    dist::S
end

function (dist::TokenSort)(s1::Union{AbstractString, Missing}, s2::Union{AbstractString, Missing})
    (s1 === missing) | (s2 === missing) && return missing
    s1 = join(sort!(split(s1)), " ")
    s2 = join(sort!(split(s2)), " ")
    out = dist.dist(s1, s2)
end

function normalize(dist::TokenSort; max_dist = 1.0)
    TokenSort(normalize(dist.dist; max_dist = max_dist))
end

"""
   TokenSet(dist)

Creates the `TokenSet{dist}` distance, which is only defined on AbstractStrings.

`TokenSet{dist}` returns the minimum the distances between:
[SORTED_INTERSECTION]
[SORTED_INTERSECTION] + [SORTED_REST_OF_STRING1]
[SORTED_INTERSECTION] + [SORTED_REST_OF_STRING2]
See: http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/

### Examples
```julia-repl
julia> s1 = "New York Mets vs Atlanta"
julia> s2 = "Atlanta Braves vs New York Mets"
julia> TokenSet(RatcliffObershelp())(s1, s2)
0.0
```
"""
struct TokenSet{S <: SemiMetric} <: SemiMetric
    dist::S
end

function (dist::TokenSet)(s1::Union{AbstractString, Missing}, s2::Union{AbstractString, Missing})
    (s1 === missing) | (s2 === missing) && return missing
    v1 = unique!(sort!(split(s1)))
    v2 = unique!(sort!(split(s2)))
    v0 = intersect(v1, v2)
    s0 = join(v0, " ")
    s1 = join(v1, " ")
    s2 = join(v2, " ")
    isempty(s0) && return dist.dist(s1, s2)
    score_01 = dist.dist(s0, s1)
    score_02 = dist.dist(s0, s2)
    score_12 = dist.dist(s1, s2)
    min(score_01, score_02, score_12)
end

function normalize(dist::TokenSet; max_dist = 1.0)
    TokenSet(normalize(dist.dist; max_dist = max_dist))
end


"""
   TokenMax(dist)

Creates the `TokenMax{dist}` distance, which is only defined on AbstractStrings.

`TokenMax{dist}` normalizes the distance `dist` and returns the minimum of the distance,
its [`Partial`](@ref) modifier, its [`TokenSort`](@ref) modifier, and its 
[`TokenSet`](@ref) modifier, with penalty terms depending on the strings lengths.


### Examples
```julia-repl
julia> s1 = "New York Mets vs Atlanta"
julia> s2 = "Atlanta Braves vs New York Mets"
julia> evaluate(TokenMax(RatcliffObershelp()), s1, s2)
0.05
```
"""
struct TokenMax{S <: SemiMetric} <: SemiMetric
    dist::S
    max_dist::Float64
end
TokenMax(dist::SemiMetric; max_dist = 1.0) = TokenMax(dist, max_dist)

function (dist::TokenMax)(s1::Union{AbstractString, Missing}, s2::Union{AbstractString, Missing})
    (s1 === missing) | (s2 === missing) && return missing
    s1, s2 = reorder(s1, s2)
    len1, len2 = length(s1), length(s2)
    max_dist = dist.max_dist
    dist0 = normalize(dist.dist; max_dist = max_dist)
    score = dist0(s1, s2)
    min_score = min(max_dist, score)
    unbase_scale = 0.95
    # if one string is much shorter than the other, use partial
    if length(s2) >= 1.5 * length(s1)
        partial_scale = length(s2) > (8 * length(s1)) ? 0.6 : 0.9
        dist0 = normalize(dist0, max_dist = 1 - (1 - max_dist) / partial_scale)
        score_partial = 1 - partial_scale * (1 - Partial(dist0)(s1, s2))
        min_score = min(max_dist, score_partial)
        dist0 = normalize(dist0, max_dist = 1 - (1 - max_dist) / (unbase_scale * partial_scale))
        score_sort = 1 - unbase_scale * partial_scale * (1 - TokenSort(Partial(dist0))(s1, s2))
        max_dist = min(max_dist, score_sort)
        dist0 = normalize(dist0, max_dist = 1 - (1 - max_dist) / (unbase_scale * partial_scale))
        score_set = 1 - unbase_scale * partial_scale * (1 - TokenSet(Partial(dist0))(s1, s2)) 
        out = min(score, score_partial, score_sort, score_set)
    else
        dist0 = normalize(dist0, max_dist = 1 - (1 - max_dist) / unbase_scale)
        score_sort = 1 - unbase_scale * (1 - TokenSort(dist0)(s1, s2))
        max_dist = min(max_dist, score_sort)
        dist0 = normalize(dist0, max_dist = 1 - (1 - max_dist) / unbase_scale)
        score_set = 1 - unbase_scale * (1 - TokenSet(dist0)(s1, s2))
        out = min(score, score_sort, score_set)
    end
    out > max_dist ? 1.0 : out
end

function normalize(dist::TokenMax; max_dist = 1.0)
    TokenMax(dist.dist, max_dist)
end