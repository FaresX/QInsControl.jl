function resize_callback(data_ptr::Ptr{ImGuiInputTextCallbackData})::Cint
    data = unsafe_load(data_ptr)
    if data.EventFlag == ImGuiInputTextFlags_CallbackResize
        str_pp = Ptr{Ptr{Cchar}}(data.UserData)
        str_p = unsafe_load(str_pp)
        str_arr = unsafe_wrap(Array, str_p, data.BufTextLen)
        resize!(str_arr, data.BufSize)
        str_arr_p = pointer(str_arr)
        data_ptr.Buf = str_arr_p
        unsafe_store!(str_pp, str_arr_p)
    end
    return 0
end
let
    resize_callback_c = @cfunction(resize_callback, Cint, (Ptr{ImGuiInputTextCallbackData},))
    push!(init_funcs, () -> resize_callback_c = @cfunction(resize_callback, Cint, (Ptr{ImGuiInputTextCallbackData},)))
    global function InputTextRSZ(label, str::Ref{String}, flags=0)
        str_p = pointer(str[])
        str_p_arr = [str_p]
        input = GC.@preserve str_p_arr CImGui.InputText(
            label, str_p, length(str[]), flags | ImGuiInputTextFlags_CallbackResize, resize_callback_c, str_p_arr
        )
        input && (str[] = unsafe_string(only(str_p_arr)))
        return input
    end
    global function InputTextWithHintRSZ(label, hint, str::Ref{String}, flags=0)
        str_p = pointer(str[])
        str_p_arr = [str_p]
        input = GC.@preserve str_p_arr CImGui.InputTextWithHint(
            label, hint, str_p, length(str[]), flags | ImGuiInputTextFlags_CallbackResize, resize_callback_c, str_p_arr
        )
        input && (str[] = unsafe_string(only(str_p_arr)))
        return input
    end
    global function InputTextMultilineRSZ(label, str::Ref{String}, size=(0, 0), flags=0)
        str_p = pointer(str[])
        str_p_arr = [str_p]
        input = GC.@preserve str_p_arr CImGui.InputTextMultiline(
            label, str_p, length(str[]), size, flags | ImGuiInputTextFlags_CallbackResize, resize_callback_c, str_p_arr
        )
        input && (str[] = unsafe_string(only(str_p_arr)))
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