CImGui.PushStyleColor(idx, col::Vector) = CImGui.PushStyleColor(idx, CImGui.ImVec4(col...))
CImGui.PushStyleVar(idx, val::Vector) = CImGui.PushStyleVar(idx, CImGui.ImVec2(val...))
CImGui.BeginChild(str_id, size::Vector, child_flags=0, window_flags=0) = CImGui.BeginChild(str_id, CImGui.ImVec2(size...), child_flags, window_flags)
CImGui.SetCursorPos(x, y) = CImGui.SetCursorPos(CImGui.ImVec2(x, y))
CImGui.SetCursorPos(local_pos::Vector) = CImGui.SetCursorPos(CImGui.ImVec2(local_pos...))
CImGui.SetCursorScreenPos(x, y) = CImGui.SetCursorScreenPos(CImGui.ImVec2(x, y))
CImGui.SetCursorScreenPos(pos::Vector) = CImGui.SetCursorScreenPos(CImGui.ImVec2(pos...))
CImGui.SetNextWindowSize(size::Vector, cond=0) = CImGui.SetNextWindowSize(CImGui.ImVec2(size...), cond)
CImGui.ColorConvertFloat4ToU32(in) = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(in...))
CImGui.TextColored(col::Vector, fmt) = CImGui.TextColored(CImGui.ImVec4(col...), fmt)
CImGui.VSliderInt(label, size::Vector, v, v_min, v_max, format="%d", flags=0) = CImGui.VSliderInt(label, CImGui.ImVec2(size...), v, v_min, v_max, format, flags)
CImGui.Button(label, size::Vector) = CImGui.Button(label, CImGui.ImVec2(size...))
CImGui.ProgressBar(fraction, size_arg::Vector, overlay=C_NULL) = CImGui.ProgressBar(fraction, CImGui.ImVec2(size_arg...), overlay)
function CImGui.ImageButton(
    str_id, user_texture_id,
    image_size::Union{ImVec2,NTuple{2},Vector},
    uv0::Union{ImVec2,NTuple{2},Vector}=[0, 0],
    uv1::Union{ImVec2,NTuple{2},Vector}=[1, 1],
    bg_col::Union{ImVec4,NTuple{4},Vector}=[0, 0, 0, 0],
    tint_col::Union{ImVec4,NTuple{4},Vector}=[1, 1, 1, 1])
    CImGui.ImageButton(
        str_id, user_texture_id,
        CImGui.ImVec2(image_size...),
        CImGui.ImVec2(uv0...),
        CImGui.ImVec2(uv1...),
        CImGui.ImVec4(bg_col...),
        CImGui.ImVec4(tint_col...)
    )
end
function CImGui.AddText(
    self,
    pos::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector},
    text_begin, text_end=C_NULL
)
    CImGui.AddText(self, CImGui.ImVec2(pos...), CImGui.ColorConvertFloat4ToU32(col), text_begin, text_end)
end
function CImGui.AddText(
    self, font, font_size,
    pos::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector},
    text_begin, text_end=C_NULL, wrap_width=0.0, cpu_fine_clip_rect = C_NULL
)
    CImGui.AddText(
        self, font, font_size, CImGui.ImVec2(pos...), CImGui.ColorConvertFloat4ToU32(col),
        text_begin, text_end, wrap_width, cpu_fine_clip_rect
    )
end
function CImGui.AddImage(
    self, user_texture_id,
    p_min::Union{ImVec2,NTuple{2},Vector},
    p_max::Union{ImVec2,NTuple{2},Vector},
    uv_min::Union{ImVec2,NTuple{2},Vector}=[0, 0],
    uv_max::Union{ImVec2,NTuple{2},Vector}=[1, 1],
    col::Union{ImVec4,NTuple{4},Vector}=[1, 1, 1, 1]
)
    CImGui.AddImage(
        self, user_texture_id, CImGui.ImVec2(p_min...), CImGui.ImVec2(p_max...),
        CImGui.ImVec2(uv_min...), CImGui.ImVec2(uv_max...), CImGui.ColorConvertFloat4ToU32(col)
    )
end
function CImGui.AddLine(
    self,
    p1::Union{ImVec2,NTuple{2},Vector},
    p2::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector},
    thickness=1.0
)
    CImGui.AddLine(self, CImGui.ImVec2(p1...), CImGui.ImVec2(p2...), CImGui.ColorConvertFloat4ToU32(col), thickness)
end
function CImGui.AddRect(
    self,
    p_min::Union{ImVec2,NTuple{2},Vector},
    p_max::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector},
    rounding=0.0, flags=0, thickness=1.0
)
    CImGui.AddRect(
        self, CImGui.ImVec2(p_min...), CImGui.ImVec2(p_max...),
        CImGui.ColorConvertFloat4ToU32(col), rounding, flags, thickness
    )
end
function CImGui.AddRectFilled(
    self,
    p_min::Union{ImVec2,NTuple{2},Vector},
    p_max::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector},
    rounding=0.0, flags=0
)
    CImGui.AddRectFilled(
        self, CImGui.ImVec2(p_min...), CImGui.ImVec2(p_max...),
        CImGui.ColorConvertFloat4ToU32(col), rounding, flags
    )
end
function CImGui.AddTriangle(
    self,
    p1::Union{ImVec2,NTuple{2},Vector},
    p2::Union{ImVec2,NTuple{2},Vector},
    p3::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector},
    thickness=1.0
)
    CImGui.AddTriangle(
        self, CImGui.ImVec2(p1...), CImGui.ImVec2(p2...), CImGui.ImVec2(p3...),
        CImGui.ColorConvertFloat4ToU32(col), thickness
    )
end
function CImGui.AddTriangleFilled(
    self,
    p1::Union{ImVec2,NTuple{2},Vector},
    p2::Union{ImVec2,NTuple{2},Vector},
    p3::Union{ImVec2,NTuple{2},Vector},
    col::Union{ImVec4,NTuple{4},Vector}
)
    CImGui.AddTriangleFilled(
        self, CImGui.ImVec2(p1...), CImGui.ImVec2(p2...), CImGui.ImVec2(p3...),
        CImGui.ColorConvertFloat4ToU32(col)
    )
end
function CImGui.AddCircle(
    self,
    center::Union{ImVec2,NTuple{2},Vector},
    radius,
    col::Union{ImVec4,NTuple{4},Vector},
    num_segments=0, thickness=1.0
)
    CImGui.AddCircle(
        self, CImGui.ImVec2(center...), radius, CImGui.ColorConvertFloat4ToU32(col), num_segments, thickness
    )
end
function CImGui.AddCircleFilled(
    self,
    center::Union{ImVec2,NTuple{2},Vector},
    radius,
    col::Union{ImVec4,NTuple{4},Vector},
    num_segments=0
)
    CImGui.AddCircleFilled(self, CImGui.ImVec2(center...), radius, CImGui.ColorConvertFloat4ToU32(col), num_segments)
end
function CImGui.PathArcTo(self, center::Vector, radius, a_min, a_max, num_segments=0)
    CImGui.PathArcTo(self, CImGui.ImVec2(center...), radius, a_min, a_max, num_segments)
end

function Base.iterate(v::ImVec2, state=1)
    if state == 1
        return v.x, 2
    elseif state == 2
        return v.y, 3
    else
        return nothing
    end
end
function Base.getindex(v::ImVec2, i)
    if i == 1
        return v.x
    elseif i == 2
        return v.y
    else
        throw(BoundsError(v, i))
    end
end
Base.length(::ImVec2) = 2
Base.convert(::Type{Vector{Cfloat}}, x::ImVec2) = collect(Cfloat, x)
function Base.getindex(v::ImVec4, i)
    if i == 1
        return v.x
    elseif i == 2
        return v.y
    elseif i == 3
        return v.z
    elseif i == 4
        return v.w
    else
        throw(BoundsError(v, i))
    end
end
Base.convert(::Type{Vector{Cfloat}}, x::ImVec4) = collect(Cfloat, x)