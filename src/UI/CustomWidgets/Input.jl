# toint8(s) = [Int8(c) for c in s]

let
    strbuf::String = '\0'^1024
    # global function ResizeCallback(data::CImGui.ImGuiInputTextCallbackData)::Cint
    #     if data.EventFlag == CImGui.ImGuiInputTextFlags_CallbackResize
    #         occursin('\0', unsafe_pointer_to_objref(Ptr{Cchar}(data.UserData))) || (buf *= '\0')
    #         # str = unsafe_pointer_to_objref(Ptr{Cchar}(data.UserData))
    #         # if ncodeunits(str) == data.BufSize
    #         #     unsafe_store!(data.Buf, '\0', data.BufSize+1)
    #         # end
    #         # @info typeof(str)
    #         # occursin('\0', str) && 
    #         # @info str
    #         # @info occursin('\0', str)
    #         # @info unsafe_string(Ptr{Cchar}(data.Buf))
    #         # strbuf = unsafe_wrap(Vector{Int8}, data.Buf, data.BufSize)
    #         # resize!(strbuf, data.BufTextLen+1)
    #         # data.Buf = pointer(strbuf)
    #         # data.BufSize = length(strbuf)
    #     end
    #     return 0
    # end
    global function InputTextRSZ(label, str::Ref{String}, flags=0)
        buf = string(str[], strbuf)
        input = CImGui.InputText(label, buf, length(buf), flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
    global function InputTextWithHintRSZ(label, hint, str::Ref{String}, flags=0)
        buf = string(str[], strbuf)
        input = CImGui.InputTextWithHint(label, hint, buf, length(buf), flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
    global function InputTextMultilineRSZ(label, str::Ref{String}, size=(0, 0), flags=0)
        buf = string(str[], strbuf)
        input = CImGui.InputTextMultiline(label, buf, length(buf), size, flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
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
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, 0, thickness)
    return input
end

# ResizeCallback_c = @cfunction ResizeCallback Cint (CImGui.ImGuiInputTextCallbackData,)

# function InputTextRSZ(label, str::Ref)
#     buf = str[] * '\0'^64
#     input = CImGui.InputText(label, buf, length(buf))
#     input && (str[] = replace(buf, r"\0.*" => ""))
#     input
# end

# function InputTextMultilineRSZ(label, str::Ref, size=(0, 0), flags=0)
#     buf = str[] * '\0'^1024
#     input = CImGui.InputTextMultiline(label, buf, length(buf), size, flags)
#     input && (str[] = replace(buf, r"\0.*" => ""))
#     input
# end

# function InputTextWithHintRSZ(label, hint, str::Ref)
#     buf = str[] * '\0'^64
#     input = CImGui.InputTextWithHint(label, hint, buf, length(buf))
#     input && (str[] = replace(buf, r"\0.*" => ""))
#     input
# end