function resize_callback(data_ptr::Ptr{ImGuiInputTextCallbackData})::Cint
    data = unsafe_load(data_ptr)
    if data.EventFlag == ImGuiInputTextFlags_CallbackResize
        # UserData 是 Ref{Vector{UInt8}} 的对象指针:缓冲区本体由调用侧 GC.@preserve 保活,
        # 这里原地 resize! 同一数组(而不是弃引用换新缓冲,旧实现重分配后的内存无人持有,
        # 回调返回即可能被 GC 回收,ImGui 后续写入成为悬垂写)
        bufref = unsafe_pointer_to_objref(Ptr{Any}(data.UserData))::Ref{Vector{UInt8}}
        buf = bufref[]
        data.BufSize > length(buf) && resize!(buf, data.BufSize)
        data.BufTextLen + 1 <= length(buf) && (buf[data.BufTextLen+1] = 0) # 维持 C 约定的 NUL 终止
        data_ptr.Buf = pointer(buf)
    end
    return 0
end
let
    resize_callback_c = @cfunction(resize_callback, Cint, (Ptr{ImGuiInputTextCallbackData},))
    push!(init_funcs, () -> resize_callback_c = @cfunction(resize_callback, Cint, (Ptr{ImGuiInputTextCallbackData},)))
    "字符串 → 自有字节缓冲(含 NUL),长度按字节计:多字节(中文)内容按字符数传 buf_size 会被 ImGui 截断"
    function str2buf(s::AbstractString)
        buf = Vector{UInt8}(undef, ncodeunits(s) + 1)
        copyto!(buf, 1, codeunits(String(s)), 1, ncodeunits(s))
        buf[end] = 0
        return buf
    end
    global function InputTextRSZ(label, str::Ref{String}, flags=0)
        buf = str2buf(str[])
        bufref = Ref(buf)
        input = GC.@preserve buf bufref CImGui.InputText(
            label, pointer(buf), length(buf), flags | ImGuiInputTextFlags_CallbackResize,
            resize_callback_c, pointer_from_objref(bufref)
        )
        input && (str[] = unsafe_string(pointer(buf)))
        return input
    end
    global function InputTextWithHintRSZ(label, hint, str::Ref{String}, flags=0)
        buf = str2buf(str[])
        bufref = Ref(buf)
        input = GC.@preserve buf bufref CImGui.InputTextWithHint(
            label, hint, pointer(buf), length(buf), flags | ImGuiInputTextFlags_CallbackResize,
            resize_callback_c, pointer_from_objref(bufref)
        )
        input && (str[] = unsafe_string(pointer(buf)))
        return input
    end
    global function InputTextMultilineRSZ(label, str::Ref{String}, size=(0, 0), flags=0)
        buf = str2buf(str[])
        bufref = Ref(buf)
        input = GC.@preserve buf bufref CImGui.InputTextMultiline(
            label, pointer(buf), length(buf), size, flags | ImGuiInputTextFlags_CallbackResize,
            resize_callback_c, pointer_from_objref(bufref)
        )
        input && (str[] = unsafe_string(pointer(buf)))
        return input
    end
end

function ColoredInputTextWithHintRSZ(
    label,
    hint,
    str::Ref{String},
    flags=0;
    size=(0, 0),
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colhint=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled),
    colrect=(0, 0, 0, 0)
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleColor(CImGui.ImGuiCol_TextDisabled, colhint)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (unsafe_load(IMGUISTYLE.FramePadding.x), (size[2] - CImGui.GetFontSize()) / 2))
    CImGui.PushItemWidth(size[1])
    input = InputTextWithHintRSZ(label, hint, str, flags)
    CImGui.PopItemWidth()
    CImGui.PopStyleVar(2)
    CImGui.PopStyleColor(3)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
    return input
end