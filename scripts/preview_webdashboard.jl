# 无头预览 Web 仪表盘（不需要打开桌面 GUI）
# 用法: julia --project=. scripts/preview_webdashboard.jl [port]
# 首次运行会在临时目录生成一个演示 .qdt（真实 JLD2 测量数据格式），浏览器打开打印出的地址即可
# 看到 live 模式：Browse 页加载该文件绘制真实数据列。
using QInsControl
using JLD2

port = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 8941
work = joinpath(tempdir(), "qinscontrol-webdash-demo")
isdir(work) || mkpath(work)
f = joinpath(work, "[2026-09-12 10.00.00] Task 1 变温输运演示.qdt")
if !isfile(f)
    n = 20000
    T = [1.4 + (300 - 1.4) * (i / n)^0.85 for i in 0:n-1]
    R = [82 + 0.88 * t^1.32 + 0.4 * sin(i / 50) + 0.3 * randn() for (i, t) in enumerate(T)]
    data = Dict{String,Vector{String}}(
        "x/K2000/Resistance/GPIB0::16::INSTR" => string.(round.(R; digits = 4)),
        "x/LS336/TempA/TCPIP0::192.168.1.12" => string.(round.(T; digits = 4))
    )
    daq = QInsControl.DAQTask(name = "变温输运演示", explog = "WebDashboard 演示数据（真实 JLD2 格式）\n1.4K → 300K, K2000 四线法")
    jldsave(f; data = data, daqtask = daq, valid = true)
    @info "demo dataset written" file = f
end
QInsControl.WORKPATH = work
url = QInsControl.startwebdashboard!(port = port)
if isempty(url)
    @error "web dashboard failed to start"
    exit(1)
end
println(stderr, "WEBDASH_URL=$(url)")
while true
    sleep(10)
end
