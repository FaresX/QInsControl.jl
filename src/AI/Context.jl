# 实验上下文快照:让 AI 知道"实验台上有什么"。全部经 Bridge 取数,带截断保护。

clip(s::AbstractString, n::Int) = length(s) <= n ? String(s) : String(first(s, n)) * "\n  ...[truncated]"

function snapshot()
    parts = String[]
    push!(parts, "## Current experiment context (auto-injected; use these exact names)")
    aliases = ai_alias_table()
    push!(parts, "Aliases (alias => instrument, address; a script can ONLY address instruments through an alias):")
    isempty(aliases) ? push!(parts, "  (none)") :
    foreach(t -> push!(parts, "  \"$(t[1])\" => \"$(t[2])\", \"$(t[3])\""), aliases)
    push!(parts, "Registered instruments & quantities (cmdheader is the underlying SCPI/TSP command):")
    push!(parts, clip(ai_instrument_summary(aiconf().withhelp), 30000))
    aliased = Set(t[2] for t in aliases)
    noalias = [k for k in ai_instrument_names() if !(k in aliased)]
    if !isempty(noalias)
        push!(parts, "Instruments WITHOUT an alias (offer to create one via the add_alias tool instead of asking the user):")
        push!(parts, "  " * join(noalias, ", "))
    end
    push!(parts, "Data keys currently in buffer:")
    push!(parts, clip(ai_data_keys(), 4000))
    push!(parts, "Tasks in project:")
    push!(parts, clip(ai_task_list(), 2000))
    push!(parts, "Reply language: " * ai_language() * ".")
    return join(parts, "\n")
end
