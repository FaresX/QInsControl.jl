types = [
    :InstrQuantity, :InstrBuffer, :InstrBufferViewer,
    :DAQTask, :NodeEditor, :Node, :UIPlot, :Layout, :Annotation, :DataPicker,
    :MoreStyle, :MoreStyleColor, :MoreStyleIcon, :UnionStyle,
    :CodeBlock, :StrideCodeBlock, :SweepBlock, :SettingBlock, :ReadingBlock,
    :LogBlock, :WriteBlock, :QueryBlock, :ReadBlock, :SaveBlock
]

for T in types
    JLD2T = Symbol(:JLD2, T)
    eval(quote
        struct $JLD2T
            fieldnames_dict::Dict
        end
        JLD2.writeas(::Type{$T}) = $JLD2T
        JLD2.wconvert(::Type{$JLD2T}, obj::$T) = $JLD2T(Dict(fdnm => getproperty(obj, fdnm) for fdnm in fieldnames($T)))
        function JLD2.rconvert(::Type{$T}, jld2obj::$JLD2T)
            obj = $T()
            fdnms = fieldnames($T)
            for fdnm in keys(jld2obj.fieldnames_dict)
                fdnm in fdnms && setproperty!(obj, fdnm, jld2obj.fieldnames_dict[fdnm])
            end
            obj
        end
    end)
end