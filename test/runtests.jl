# 上下文自适应:常规测试运行(Pkg.test / create_app 执行文件)正常 import QInsControl;
# 深预编译上下文(QIC_DEEP_PRECOMPILE=1 时 runtests.jl 被 @compile_workload include),
# 模块正在自身预编译中,`import QInsControl` 不可用,以 @__MODULE__ 充当 qic——
# 测试体引用的 mlstr/MORESTYLE/string 等绑定在自身模块内天然可见,无需 import。
const GENERATING = ccall(:jl_generating_output, Cint, ()) == 1
if GENERATING
    const qic = @__MODULE__
else
    import QInsControl as qic
    import QInsControl: string, mlstr, MORESTYLE
end
import CImGui as ig
import OrderedCollections: OrderedDict
using ImGuiTestEngine
import ImGuiTestEngine as te
import ImGuiTestEngine: WindowInfo, WindowClose, ItemOpen, ItemInputValue
using Test

@testset "QInsControl.jl" begin
    # @test qic.JLD2.load(joinpath(@__DIR__, "../example/demo.daq")) isa Dict

    @testset "Tree" begin
        #构造：根 + 顶层叶子 + 一级分类
        root = qic.TreeGroup(qic.DAQTask, "root")
        t1 = qic.Tree(qic.DAQTask(name="t1"))
        t1.value.torunstate = true
        group = qic.TreeGroup(qic.DAQTask, "g")
        group.open = true
        push!(group.children, qic.Tree(qic.DAQTask(name="t2")))
        push!(root.children, t1)
        push!(root.children, group)
        @test length(qic.leaves(root)) == 2
        @test [t.name for t in qic.leafvalues(root)] == ["t1", "t2"]
        @test qic.leaves(root)[1].value.torunstate
        @test sizeof(qic.TreeDragPayload) == 8
        #顶层叶子移入分类（group 0 为顶层，分类索引按 root.children 计）
        qic.moveleaf!(root, 0, 1, 2, 1)
        @test length(root.children) == 1
        @test [t.name for t in qic.leafvalues(root)] == ["t1", "t2"]
        #JLD2 往返（新格式 Tree{DAQTask}）
        tmppath = joinpath(mktempdir(), "tree.daq")
        qic.JLD2.jldsave(tmppath; daqtasks=root)
        loaded = qic.JLD2.load(tmppath, "daqtasks")
        @test loaded isa qic.Tree{qic.DAQTask}
        @test loaded.children[1].isgroup && loaded.children[1].name == "g" && loaded.children[1].open
        @test [t.name for t in qic.leafvalues(loaded)] == ["t1", "t2"]
        @test loaded.children[1].children[1].value.torunstate
        #删除分类（叶子移回顶层）
        qic.ungroup!(root, 1)
        @test [t.name for t in qic.leafvalues(root)] == ["t1", "t2"]
        @test !any(c.isgroup for c in root.children)
    end

    @testset "ProjectFolder" begin
        tmp = mktempdir()
        #文件名清洗：非法字符/保留名/空名
        @test qic.sanitizefilename("a/b\\c:d*e?f\"g<h>i|j") == "a_b_c_d_e_f_g_h_i_j"
        @test qic.sanitizefilename("CON") == "CON_"
        @test qic.sanitizefilename("  .x. ") == "x"
        @test qic.sanitizefilename("") == "unnamed"
        used = Set{String}()
        @test qic.uniquename(used, "task", ".task") == "task.task"
        @test qic.uniquename(used, "task", ".task") == "task-2.task"
        #构造小工程并保存
        tasksroot = qic.TreeGroup(qic.DAQTask, "root")
        t1 = qic.Tree(qic.DAQTask(name="顶层任务", explog="note"))
        push!(tasksroot.children, t1)
        group = qic.TreeGroup(qic.DAQTask, "分类A")
        push!(group.children, qic.Tree(qic.DAQTask(name="分类任务")))
        push!(tasksroot.children, group)
        plotsroot = qic.TreeGroup(qic.DataPlot, "root")
        push!(plotsroot.children, qic.Tree(qic.DataPlot(name="plot1")))
        circuit = qic.NodeEditor()
        aliases = OrderedDict("Virtual" => qic.InstrAlias(alias="Virtual", instrnm="VirtualInstr", addr="VIRTUAL::ADDRESS"))
        projdir = joinpath(tmp, "proj")
        @test isempty(qic.save_project_folder(projdir, tasksroot, plotsroot, circuit, aliases))
        @test qic.probe_project(projdir)[1] == :project
        @test qic.classify_project_dir(projdir) == :project
        #往返：顺序/分组/内容一致
        r = qic.load_project_folder(projdir)
        @test r.ok && r.reason == :ok && isempty(r.failures) && isempty(r.warnings)
        @test [t.name for t in qic.leafvalues(r.tasks)] == ["顶层任务", "分类任务"]
        @test r.tasks.children[2].isgroup && r.tasks.children[2].name == "分类A"
        @test [t.explog for t in qic.leafvalues(r.tasks)] == ["note", ""]
        @test [p.name for p in qic.leafvalues(r.plots)] == ["plot1"]
        @test r.circuit isa qic.NodeEditor
        @test haskey(r.aliases, "Virtual") && r.aliases["Virtual"].addr == "VIRTUAL::ADDRESS"
        #顶层混排顺序（回归:裸任务与文件夹穿插时,v1 清单双列表曾丢失两者间相对顺序,加载端固定叶子在前）
        mix = qic.TreeGroup(qic.DAQTask, "root")
        push!(mix.children, qic.Tree(qic.DAQTask(name="A")))
        gmix = qic.TreeGroup(qic.DAQTask, "G")
        push!(gmix.children, qic.Tree(qic.DAQTask(name="B")))
        push!(mix.children, gmix)
        push!(mix.children, qic.Tree(qic.DAQTask(name="C")))
        mixdir = joinpath(tmp, "mix")
        @test isempty(qic.save_project_folder(mixdir, mix, qic.TreeGroup(qic.DataPlot, "root"), qic.NodeEditor(), OrderedDict()))
        rmix = qic.load_project_folder(mixdir)
        @test [t.name for t in qic.leafvalues(rmix.tasks)] == ["A", "B", "C"]
        @test !rmix.tasks.children[1].isgroup && !rmix.tasks.children[3].isgroup
        @test rmix.tasks.children[2].isgroup && rmix.tasks.children[2].name == "G"
        #v1 旧清单兼容:order+groups 双列表仍可读（混排退化为叶子在前、文件夹在后,清单外文件记 warnings）
        open(joinpath(mixdir, "project.toml"), "w") do io
            write(
                io,
                """
      formatversion = 1
      [tasks]
      order = ["A.task"]
          [[tasks.groups]]
          name = "G"
          dir = "G"
          order = ["B.task"]
      [plots]
      order = []
      """
            )
        end
        r1 = qic.load_project_folder(mixdir)
        @test r1.ok && [t.name for t in qic.leafvalues(r1.tasks)] == ["A", "B"]
        #重命名后再保存：旧文件清理、新文件生成
        t1.value.name = "改名任务"
        @test isempty(qic.save_project_folder(projdir, tasksroot, plotsroot, circuit, aliases))
        @test !isfile(joinpath(projdir, "tasks", "顶层任务.task"))
        @test isfile(joinpath(projdir, "tasks", "改名任务.task"))
        #保存目标判定：不存在=:empty；非空非工程=:foreign，加载被拒
        @test qic.classify_project_dir(joinpath(tmp, "missing")) == :empty
        foreign = joinpath(tmp, "foreign")
        mkdir(foreign)
        write(joinpath(foreign, "foo.txt"), "x")
        @test qic.classify_project_dir(foreign) == :foreign
        rf = qic.load_project_folder(foreign)
        @test !rf.ok && rf.reason == :foreign
        @test qic.load_project_folder(joinpath(tmp, "missing")).reason == :notdir
        #损坏隔离：单个部件损坏只记 failures，其余照常加载（故意触发的部件损坏报错用 NullLogger 静音）
        rm(joinpath(projdir, "tasks", "改名任务.task"))
        write(joinpath(projdir, "tasks", "改名任务.task"), "garbage")
        rc = Base.with_logger(Base.NullLogger()) do
            qic.load_project_folder(projdir)
        end
        @test rc.ok && length(rc.failures) == 1 && occursin("改名任务", only(rc.failures))
        @test [t.name for t in qic.leafvalues(rc.tasks)] == ["分类任务"]
        #清单损坏/缺失 → 修复扫描（损坏文件同样被跳过并记录）
        rm(joinpath(projdir, "project.toml"))
        rr = Base.with_logger(Base.NullLogger()) do
            qic.load_project_folder(projdir)
        end
        @test rr.ok && !isempty(rr.warnings)
        @test [t.name for t in qic.leafvalues(rr.tasks)] == ["分类任务"]
        @test length(rr.failures) == 1
        #GUI 包装函数链路（工具栏/菜单同款路径,显式文件夹分支不弹对话框,headless 可跑）:
        #加载 → 内存重排 → saveproject → loadproject,顺序必须持久化（回归:拖拽重排保存后丢失）
        guidir = joinpath(tmp, "gui")
        gtasks = qic.TreeGroup(qic.DAQTask, "root")
        push!(gtasks.children, qic.Tree(qic.DAQTask(name="T1")))
        ggroup = qic.TreeGroup(qic.DAQTask, "组B")
        push!(ggroup.children, qic.Tree(qic.DAQTask(name="T2")))
        push!(gtasks.children, ggroup)
        @test isempty(qic.save_project_folder(guidir, gtasks, qic.TreeGroup(qic.DataPlot, "root"), qic.NodeEditor(), OrderedDict()))
        qic.loadproject(guidir)
        @test [t.name for t in qic.leafvalues(qic.taskroot())] == ["T1", "T2"]
        qic.moveleaf!(qic.taskroot(), 2, 1, 0, 1) #组内 T2 提到顶层第一（gi 为 children 索引,2 即"组B"）
        @test isempty(qic.saveproject(guidir))
        @test [t.name for t in qic.leafvalues(qic.load_project_folder(guidir).tasks)] == ["T2", "T1"]
        qic.loadproject(guidir)
        @test [t.name for t in qic.leafvalues(qic.taskroot())] == ["T2", "T1"]
        @test qic.taskroot().children[3].isgroup #顶层混排:文件夹在叶子之后的位置同样持久化
    end

    @testset "CodeEditor" begin
        #分词：关键字/数字/注释
        t = "if x == 1 # note"
        spans = qic.codetokenize!(qic.CodeSpan[], t, Ref((false, 0)))
        getk(t, sp) = String(collect(t)[sp.first:sp.last])
        @test any(sp -> sp.kind == qic.CODE_KEYWORD && getk(t, sp) == "if", spans)
        @test any(sp -> sp.kind == qic.CODE_NUMBER && getk(t, sp) == "1", spans)
        @test any(sp -> sp.kind == qic.CODE_COMMENT && getk(t, sp) == "# note", spans)
        #字符串内的 # 不是注释
        t2 = "s = \"a # b\""
        spans2 = qic.codetokenize!(qic.CodeSpan[], t2, Ref((false, 0)))
        @test !any(sp -> sp.kind == qic.CODE_COMMENT, spans2)
        @test any(sp -> sp.kind == qic.CODE_STRING && getk(t2, sp) == "\"a # b\"", spans2)
        #宏与函数调用
        t3 = "@sprintf(\"%d\", foo(1))"
        spans3 = qic.codetokenize!(qic.CodeSpan[], t3, Ref((false, 0)))
        @test any(sp -> sp.kind == qic.CODE_MACRO && getk(t3, sp) == "@sprintf", spans3)
        @test any(sp -> sp.kind == qic.CODE_FUNC && getk(t3, sp) == "foo", spans3)
        #跨行三引号字符串
        st = Ref((false, 0))
        qic.codetokenize!(qic.CodeSpan[], "s = \"\"\"abc", st)
        @test st[] == (true, 0)
        spans4 = qic.codetokenize!(qic.CodeSpan[], "def\"\"\"", st)
        @test st[] == (false, 0)
        @test spans4[1].kind == qic.CODE_STRING
        #跨行块注释（含嵌套）
        st2 = Ref((false, 0))
        qic.codetokenize!(qic.CodeSpan[], "x #= a #= b", st2)
        @test st2[] == (false, 2)
        spans5 = qic.codetokenize!(qic.CodeSpan[], "c =# =# y", st2)
        @test st2[] == (false, 0)
        @test spans5[1].kind == qic.CODE_COMMENT
        @test spans5[end].kind == qic.CODE_NORMAL #注释闭合后的 y 是正常代码
        #编辑：插入/撤销/重做
        ed = qic.CodeEditor("abc\ndef")
        @test qic._selectiontext(ed) == "abc" #无选区时复制当前行
        qic._inserttext!(ed, "X")
        @test String(ed.buf) == "Xabc\ndef" && ed.cur == 2
        qic._undo!(ed)
        @test String(ed.buf) == "abc\ndef"
        qic._redo!(ed)
        @test String(ed.buf) == "Xabc\ndef"
        #选区替换
        ed2 = qic.CodeEditor("abcdef")
        ed2.anchor = 2
        ed2.cur = 5
        qic._inserttext!(ed2, "Z")
        @test String(ed2.buf) == "aZef"
        #退格合并行
        ed3 = qic.CodeEditor("ab\ncd")
        qic._move!(ed3, 4)
        qic._backspace!(ed3)
        @test String(ed3.buf) == "abcd" && ed3.cur == 3
        #回车自动缩进
        ed4 = qic.CodeEditor("    x = 1")
        qic._move!(ed4, 10)
        qic._inserttext!(ed4, qic._newlinetext(ed4))
        @test startswith(String(ed4.buf), "    x = 1\n    ")
        #上下移动保持期望列（短行钳位）
        ed5 = qic.CodeEditor("abcdef\nxy\n123456")
        qic._move!(ed5, 4)
        qic._vertical!(ed5, 1, false)
        @test qic._lcbuf(ed5, ed5.cur) == (2, 3)
        qic._vertical!(ed5, 1, false)
        @test qic._lcbuf(ed5, ed5.cur) == (3, 4)
        #词移动与词选区
        ed6 = qic.CodeEditor("foo bar")
        qic._move!(ed6, 8)
        @test qic._wordleftix(ed6) == 5
        qic._move!(ed6, 1)
        @test qic._wordrightix(ed6) == 4
        ed7 = qic.CodeEditor("foo bar")
        qic._move!(ed7, 2)
        qic._selectword!(ed7)
        @test qic._selectiontext(ed7) == "foo"
        #Tab 整体右缩进(选区内各行)
        ed9 = qic.CodeEditor("a\nb")
        ed9.anchor = 1
        ed9.cur = 4
        qic._indentlines!(ed9)
        @test String(ed9.buf) == "\ta\n\tb"
        #Shift+Tab 左缩进
        qic._dedentlines!(ed9)
        @test String(ed9.buf) == "a\nb"
        #左缩进至多 4 个前导空格(无选区仅当前行)
        ed10 = qic.CodeEditor("      x\n\ty")
        qic._move!(ed10, 1)
        qic._dedentlines!(ed10)
        @test String(ed10.buf) == "  x\n\ty"
        qic._move!(ed10, 5)
        qic._dedentlines!(ed10)
        @test String(ed10.buf) == "  x\ny"
        #Ctrl+/ 切换注释(双向)
        ed11 = qic.CodeEditor("a = 1\nb = 2")
        ed11.anchor = 1
        ed11.cur = 12
        qic._togglecomment!(ed11)
        @test String(ed11.buf) == "# a = 1\n# b = 2"
        qic._togglecomment!(ed11)
        @test String(ed11.buf) == "a = 1\nb = 2"
        #部分行已注释 → 全部注释(VS Code 语义)
        ed12 = qic.CodeEditor("# a\nb")
        ed12.anchor = 1
        ed12.cur = 6
        qic._togglecomment!(ed12)
        @test String(ed12.buf) == "# # a\n# b"
        #选区终点恰在行首不含末行
        ed13 = qic.CodeEditor("a\nb")
        ed13.anchor = 1
        ed13.cur = 3
        qic._indentlines!(ed13)
        @test String(ed13.buf) == "\ta\nb"
        #渲染缓存重建
        ed8 = qic.CodeEditor("x = 1\ny = \"s\"")
        qic._rebuild!(ed8)
        @test length(ed8.lines) == 2
        @test ed8.linestarts == [1, 7]
        @test any(sp -> sp.kind == qic.CODE_NUMBER, ed8.spans[1])
        @test any(sp -> sp.kind == qic.CODE_STRING, ed8.spans[2])
    end

    @testset "Markdown" begin
        #行内:粗体/斜体/行内代码/删除/链接/转义
        sp = qic._mdparseinline("**bold** and *it* end")
        @test [x.style for x in sp] == [:bold, :normal, :italic, :normal]
        @test sp[1].text == "bold" && sp[3].text == "it"
        sp = qic._mdparseinline("`**no**`x")
        @test length(sp) == 2 && sp[1].style == :code && sp[1].text == "**no**" && sp[2].text == "x"
        sp = qic._mdparseinline("~~gone~~ [link](http://x.cn/中文)")
        @test sp[1].style == :strike && sp[1].text == "gone"
        @test sp[3].style == :link && sp[3].url == "http://x.cn/中文" && sp[3].text == "link"
        sp = qic._mdparseinline("\\*not italic\\* **真粗体**")
        @test [sp[i].text for i in 1:4] == ["*", "not italic", "*", " "]
        @test sp[5].style == :bold && sp[5].text == "真粗体"
        #词内下划线不作斜体;粗体内嵌行内代码
        sp = qic._mdparseinline("foo_bar_baz **use `getU`**")
        @test sp[1].style == :normal && sp[1].text == "foo_bar_baz "
        @test sp[2].style == :bold && sp[2].text == "use " && sp[3].style == :code && sp[3].text == "getU"

        #块级:标题/段落
        blocks = qic.parsemarkdown("# Title\n## Sub ##\n#nospace")
        @test blocks[1] isa qic.MDHeading && blocks[1].level == 1 && blocks[1].spans[1].text == "Title"
        @test blocks[2].level == 2 && blocks[2].spans[1].text == "Sub"
        @test blocks[3] isa qic.MDParagraph
        blocks = qic.parsemarkdown("第一段\n续行\n\n新段落")
        @test length(blocks) == 2 && blocks[1].spans[1].text == "第一段 续行"

        #围栏代码块:带语言/未闭合(流式输出)
        blocks = qic.parsemarkdown("```julia\nx = 1\n```\n```python\nprint(1)")
        @test blocks[1] isa qic.MDCode && blocks[1].lang == "julia" && blocks[1].code == "x = 1"
        @test blocks[2].lang == "python" && blocks[2].code == "print(1)"

        #列表:嵌套/有序/懒续行
        blocks = qic.parsemarkdown("- a\n- b\n  - b1\n1. one\n2. two")
        @test blocks[1] isa qic.MDList && length(blocks[1].items) == 5
        @test blocks[1].items[3].level == 1 && blocks[1].items[3].marker == "-"
        @test blocks[1].items[4].marker == "1." && blocks[1].items[5].marker == "2."
        blocks = qic.parsemarkdown("- first\ncontinued line")
        @test length(blocks[1].items) == 1 && blocks[1].items[1].spans[3].text == "continued line"

        #引用/分隔线/表格
        blocks = qic.parsemarkdown("> quoted text\n> more")
        @test blocks[1] isa qic.MDQuote && blocks[1].spans[1].text == "quoted text more"
        blocks = qic.parsemarkdown("---\ntext")
        @test blocks[1] isa qic.MDHR && blocks[2] isa qic.MDParagraph
        blocks = qic.parsemarkdown("| a | b |\n|---|---:|\n| 1 | `x` |\n| 中文 | d |")
        @test blocks[1] isa qic.MDTable
        @test length(blocks[1].header) == 2 && length(blocks[1].rows) == 2
        @test blocks[1].rows[1][2][1].style == :code && blocks[1].rows[2][1][1].text == "中文"
        #紧邻段落的分隔线不误判为表格
        blocks = qic.parsemarkdown("a\n---\nb")
        @test length(blocks) == 3 && blocks[1] isa qic.MDParagraph && blocks[2] isa qic.MDHR
    end

    @testset "DataStream channels" begin
        QIC = qic.QInsControlCore
        cpu = QIC.Processor()
        cpu.running[] = true
        ct = QIC.Controller("Fake", "FAKE::0"; busytimeout=2)
        #手动"登录":绕过 instrument 工厂与 VISA 资源管理器,用 Lockable(Ref) 模拟仪器状态
        lock(() -> push!(cpu.controllers, ct), cpu.lock)
        instr = qic.Lockable(Ref("42"))
        cpu.instrs["FAKE::0"] = instr
        cpu.exechannels["FAKE::0"] = Channel{QIC.INSTRCMD}(Inf)
        cpu.taskbusy["FAKE::0"] = false
        cpu.taskhandlers["FAKE::0"] = true
        cpu.processtask[] = errormonitor(QIC._routetask(cpu))
        cpu.tasks["FAKE::0"] = errormonitor(QIC.monitorinstr(cpu, "FAKE::0"))
        #read/query/write 全链路:入队 → 分发 → 执行 → 响应通道回传
        @test ct(d -> d[], cpu, Val(:read); timeout=2) == "42"
        @test ct((d, v) -> (d[]=v; "ok"), cpu, "7", Val(:query); timeout=2) == "ok"
        @test ct(d -> d[], cpu, Val(:read); timeout=2) == "7"
        @test ct((d, v) -> (d[]=v; nothing), cpu, "9", Val(:write); timeout=2) == "" #write 不回传执行结果
        #并发调用各持独立响应通道,互不串扰(write 后状态应为 "9")
        tasks = [Threads.@spawn ct(d -> d[], cpu, Val(:read); timeout=3) for _ in 1:8]
        @test all(fetch(t) == "9" for t in tasks)
        #busy 期间命令暂缓执行,解除后继续
        QIC.setbusy!(cpu, "FAKE::0")
        @async (sleep(0.3); QIC.unsetbusy!(cpu, "FAKE::0"))
        @test ct(d -> d[], cpu, Val(:read); timeout=3) == "9"
        #超时报错且文案保持原样;迟到的孤儿结果写入被放弃的通道,不影响后续命令
        @test_throws ErrorException ct(d -> (sleep(2); d[]), cpu, Val(:read); timeout=0.3)
        sleep(2.2)
        @test ct(d -> d[], cpu, Val(:read); timeout=2) == "9"
        #停止唤醒:Val(:stop) 让阻塞在 take! 上的任务正常退出,而非被强杀
        cpu.taskhandlers["FAKE::0"] = false
        put!(cpu.exechannels["FAKE::0"], QIC._stopcmd())
        sleep(0.2)
        @test istaskdone(cpu.tasks["FAKE::0"]) && !istaskfailed(cpu.tasks["FAKE::0"])
        cpu.running[] = false
        put!(cpu.cmdchannel, QIC._stopcmd())
        sleep(0.2)
        @test istaskdone(cpu.processtask[]) && !istaskfailed(cpu.processtask[])
    end

    @testset "DataStream vectors" begin
        QIC = qic.QInsControlCore
        cpu = QIC.Processor()
        cpu.vecmode[] = true #单线程 vector 槽位模型:并发调用方用 @async 模拟协作调度(vec 模式只在单线程进程启用)
        cpu.running[] = true
        ct = QIC.Controller("Fake", "FAKE::0"; busytimeout=2, buflen=8)
        #手动"登录":绕过 instrument 工厂与 VISA 资源管理器,用 Lockable(Ref) 模拟仪器状态
        push!(cpu.controllers, ct) #vec 模式热路径无锁,直接登记
        instr = qic.Lockable(Ref("42"))
        cpu.instrs["FAKE::0"] = instr
        cpu.execqueues["FAKE::0"] = Vector{QIC.INSTRCMDV}()
        cpu.taskbusy["FAKE::0"] = false
        cpu.taskhandlers["FAKE::0"] = true
        cpu.processtask[] = errormonitor(QIC._routetask(cpu))
        cpu.tasks["FAKE::0"] = errormonitor(QIC.monitorinstr(cpu, "FAKE::0"))
        #read/query/write 全链路:抢槽 → 入队 → 轮询执行 → 槽位回传
        @test ct(d -> d[], cpu, Val(:read); timeout=2) == "42"
        @test ct((d, v) -> (d[]=v; "ok"), cpu, "7", Val(:query); timeout=2) == "ok"
        @test ct(d -> d[], cpu, Val(:read); timeout=2) == "7"
        @test ct((d, v) -> (d[]=v; nothing), cpu, "9", Val(:write); timeout=2) == "" #write 不回传执行结果
        #并发调用各抢各的槽位,互不串扰(write 后状态应为 "9")
        tasks = [@async ct(d -> d[], cpu, Val(:read); timeout=3) for _ in 1:8]
        @test all(fetch(t) == "9" for t in tasks)
        #busy 期间命令暂缓执行,解除后继续
        QIC.setbusy!(cpu, "FAKE::0")
        @async (sleep(0.3); QIC.unsetbusy!(cpu, "FAKE::0"))
        @test ct(d -> d[], cpu, Val(:read); timeout=3) == "9"
        #超时报错且文案保持原样;迟到的孤儿结果写回旧序列号,不影响后续命令(序列号机制)
        @test_throws ErrorException ct(d -> (sleep(2); d[]), cpu, Val(:read); timeout=0.3)
        sleep(2.2)
        @test ct(d -> d[], cpu, Val(:read); timeout=2) == "9"
        #vec 模式靠标志退出:置 false 后 monitor 在下一轮询周期自行结束,无需唤醒命令
        cpu.taskhandlers["FAKE::0"] = false
        sleep(0.2)
        @test istaskdone(cpu.tasks["FAKE::0"]) && !istaskfailed(cpu.tasks["FAKE::0"])
        cpu.running[] = false
        sleep(0.2)
        @test istaskdone(cpu.processtask[]) && !istaskfailed(cpu.processtask[])
    end

    @testset "AI client protocol (mock SSE)" begin
        include("ai_client_smoketest.jl")   #独立桩模块 + 本地 mock 服务器:双协议归一化/流式/孤儿消息降级/重定向/错误正文
    end

    @testset "AI integration (offline)" begin
        include("ai_integration_smoke.jl")  #全模块加载态:ai.toml/Bridge 校验通道/buildmessages/SSRF 判定回归
    end

    if GENERATING
        # 深预编译上下文跳过 ITE GUI 套件:测试电池会把代码 eval 进 Instruments 等模块,
        # 触发 1.12 增量编译副作用检查,毒化包镜像保存(实测 precompile 整体失败)。
        # 预热覆盖由前述测试集提供;完整 GUI 套件由发布构建以普通进程"暖运行"
        # (见 scripts/portable/build_portable.jl),同时充当发布质量门。
        @info "deep precompile context: skipping ITE GUI battery"
    else
        engine = te.CreateContext(; exit_on_completion=isempty(ARGS))
        engine.IO.ConfigLogToTTY = true #失败测试的日志输出到终端,便于定位
        engine.IO.ConfigVerboseLevelOnError = te.VerboseLevel_Info
        for dp in qic.plotleaves(qic.DAQDATAPLOTS)
            dp.showplot = false
        end
        @register_test(engine, "QInsControl", "InstrRegister") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Instruments)
            ItemClick(MORESTYLE.Icons.InstrumentsRegister)
            for (insnm, inscf) in qic.INSTRCONF
                insnm == "Others" && continue
                SetRef(WindowInfo("//###ins reg/Toolbar/Instruments").Window)
                ItemClick(string(inscf.conf.icon, " ", insnm))
                SetRef(WindowInfo("//###ins reg/edit qts").Window)
                if haskey(qic.INSWCONF, insnm)
                    for i in eachindex(qic.INSWCONF[insnm])
                        ItemClick(string("edit confs and widgets/", mlstr("Widget"), " ", i)) #tab 标签已本地化
                    end
                end
            end
            SetRef(WindowInfo("//###ins reg/Toolbar").Window)
            ItemClick(string(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"), "##qtcf to toml"))
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.InstrumentsRegister) #窗口无 ImGui 标题栏关闭钮,再点开关钮关闭
        end
        @register_test(engine, "QInsControl", "Instrument CPU Monitor") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Instruments)
            ItemClick(MORESTYLE.Icons.CPUMonitor)
        end
        @register_test(engine, "QInsControl", "Server Monitor") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Instruments)
            ItemClick(MORESTYLE.Icons.ServerMonitor)
            SetRef(WindowInfo("//###MainWindow/main/right/right content").Window)
            # ItemClick(mlstr("Stopped"))
            # sleep(0.1)
            # ItemClick(mlstr("Running"))
        end
        @register_test(engine, "QInsControl", "Instrument Control") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Instruments)
            ItemClick(MORESTYLE.Icons.InstrumentsSetting)
            SetRef(WindowInfo("//###MainWindow/main/right/right content/border2").Window)
            for (ins, inses) in qic.INSTRBUFFERVIEWERS
                isempty(inses) && continue
                OpenAndClose(ins) do
                    for (addr, ibv) in inses
                        OpenAndClose("$ins/$addr") do
                            ItemClick(string("$ins/$addr/", mlstr("Common")))
                            ItemClick(string("$ins/$addr/", mlstr("Common"))) #Common 窗口无标题栏关闭钮,再点开关 MenuItem 关闭
                            if haskey(qic.INSWCONF, ins)
                                for w in qic.INSWCONF[ins]
                                    ItemClick(string("$ins/$addr/", w.name))
                                    ItemClick(string("$ins/$addr/", w.name)) #再点一次开关 MenuItem 关闭部件窗口
                                end
                            end
                        end
                    end
                end
            end
        end
        @register_test(engine, "QInsControl", "Console") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Assistant) #Console 开关在 Assistant 分类下
            ItemClick(MORESTYLE.Icons.Console)
            ItemClick(MORESTYLE.Icons.Console) #窗口无标题栏关闭钮,再点开关钮关闭
        end
        @register_test(engine, "QInsControl", "Metrics") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Help)
            ItemClick(MORESTYLE.Icons.Metrics)
            ItemClick(MORESTYLE.Icons.Metrics) #再点开关钮关闭
        end
        @register_test(engine, "QInsControl", "Logger") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Help)
            ItemClick(MORESTYLE.Icons.Logger)
            ItemClick(MORESTYLE.Icons.Logger) #再点开关钮关闭
        end
        @register_test(engine, "QInsControl", "ShowAbout") do
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.Help)
            ItemClick(MORESTYLE.Icons.About)
            ItemClick(string("//\$FOCUSED/", string(mlstr("Confirm"), "##ShowAbout")))
        end
        @register_test(engine, "QInsControl", "Debugger") do
            #     qic.debugger()
            #     SetRef("//Debugger")
            #     OpenAndClose("Global Variables") do 
            #         OpenAndClose(()->(), "Global Variables/SYNCSTATES")
            #         OpenAndClose(()->(), "Global Variables/STATES")
            #         OpenAndClose(()->(), "Global Variables/Tasks")
            #         OpenAndClose(()->(), "Global Variables/###DATABUF")
            #         OpenAndClose(()->(), "Global Variables/###DATABUFPARSED")
            #         OpenAndClose(()->(), "Global Variables/###PROGRESSLIST")
            #         OpenAndClose(()->(), "Global Variables/###STYLES")
            #         OpenAndClose(()->(), "Global Variables/###MLSTRINGS")
            #         OpenAndClose(()->(), "Global Variables/###STATICSTRINGS")
            #         OpenAndClose(()->(), "Global Variables/###IMAGES")
            #         OpenAndClose(()->(), "Global Variables/###Textures")
            #         OpenAndClose(()->(), "Global Variables/###FIGURES")
            #         OpenAndClose(()->(), "Global Variables/###ImMakieFigures")
            #     end
            #     qic.closeallwindows() #Debugger 窗口没有 UI 关闭钮,统一收尾关闭
        end
        tsetup = @register_test(engine, "QInsControl", "DAQ setup")
        # 运行任务时应用会把工程自动回存到加载目录(rundaqtasks → saveproject):加载临时副本,避免测试改写 example/demo_proj
        testprojdir = joinpath(mktempdir(), "demo_proj")
        cp(joinpath(@__DIR__, "../example/demo_proj"), testprojdir)
        tsetup.GuiFunc = () -> begin
            qic.loadproject(testprojdir) #文件夹式工程(由 scripts/import_legacy_project.jl 从 demo.daq 转出)
            for dp in qic.plotleaves(qic.DAQDATAPLOTS)  # 树形化后经 plotleaves 取叶子
                dp.showplot = false
            end
            qic.WORKPATH = joinpath(@__DIR__, "TestQInsControl")
        end
        @register_test(engine, "QInsControl", "Open Plots") do
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot").Window) #绘图树直接渲染在卡片里,无内层子窗口
            for (gi, child) in enumerate(qic.DAQDATAPLOTS.children) #分组头默认折叠,先展开才能点到组内叶子
                child.isgroup && ItemOpen(string("###daqplots_group", gi))
            end
            ItemClick("###plot1")
            ItemClick("###plot2")
        end
        @register_test(engine, "QInsControl", "Render Plots") do
            SetRef(WindowInfo("//###MainWindow/main/left/queue").Window)
            ItemClick(string(MORESTYLE.Icons.Update, "##update showing plots"))
        end
        @register_test(engine, "QInsControl", "Close Plots") do
            for dp in qic.plotleaves(qic.DAQDATAPLOTS)  # 树形化后经 plotleaves 取叶子
                dp.showplot = false
            end
        end
        @register_test(engine, "QInsControl", "Pre-DataViewer") do
            empty!(QInsControl.get_fileviewers())
            path = abspath(@__DIR__)
            push!(QInsControl.get_fileviewers(), QInsControl.FileViewer(filetree=QInsControl.FolderFileTree(path)))
            OpenAndClose(string("//dtv1/**/", MORESTYLE.Icons.OpenFolder, " ", path)) do
                ItemClick(string("//dtv1/**/", MORESTYLE.Icons.OpenFile, " test1.qdt"))
                SetRef(WindowInfo(replace(string("//test1.qdt##", path, "\\test1.qdt/DataViewer"), "\\" => "\\\\")).Window)
                ItemClick(string("//dtv1/**/", MORESTYLE.Icons.OpenFile, " test1.qdt"))
            end
        end
        @register_test(engine, "QInsControl", "DataViewer") do
            path = abspath(@__DIR__)
            OpenAndClose(string("//dtv1/**/", MORESTYLE.Icons.OpenFolder, " ", path)) do
                for i in 1:2
                    ItemClick(string("//dtv1/**/", MORESTYLE.Icons.OpenFile, " test$i.qdt"))
                    SetRef(WindowInfo(replace(string("//test$i.qdt##", path, "\\test$i.qdt/DataViewer"), "\\" => "\\\\")).Window)
                    ItemClick(string("Data Viewer/", mlstr("Instrument Status")))
                    ItemClick(string("Data Viewer/", mlstr("Actions")))
                    ItemClick(string("Data Viewer/", mlstr("Script")))
                    ItemClick(string("Data Viewer/", mlstr("Circuit")))
                    ItemClick(string("Data Viewer/", mlstr("Data")))
                    ItemClick(string("Data Viewer/", mlstr("Plots")))
                    ItemClick(string("Data Viewer/", mlstr("Revision")))
                    ItemClick(string("Data Viewer/", mlstr("Information")))
                    ItemClick(string("Data Viewer/", MORESTYLE.Icons.SaveButton, " ", mlstr("Save")))
                    ItemClick(string("//dtv1/**/", MORESTYLE.Icons.OpenFile, " test$i.qdt"))
                end
            end
            SetRef(WindowInfo("//###MainWindow/main/right").Window)
            ItemClick(MORESTYLE.Icons.OpenFile)
            SetRef(WindowInfo("//###MainWindow/main/right/right content").Window)
            ItemClick("\$\$1/test", ig.ImGuiMouseButton_Right)
            ItemClick(string("//\$FOCUSED/", MORESTYLE.Icons.Delete, " ", mlstr("Close")))
        end
        @register_test(engine, "QInsControl", "DAQ") do
            # 前面某个窗口测试若被干扰残留(如 Console),会遮挡任务队列且 ITE 无法
            # 移动无边框窗口 —— 程序化兜底关闭,保证后续点击不被遮挡
            qic.closeallwindows()
            SetRef(WindowInfo("//###MainWindow/Toolbar").Window)
            ItemClick(string(MORESTYLE.Icons.Circuit, "##circuit"))
            ItemClick(string(MORESTYLE.Icons.Circuit, "##circuit")) #窗口无标题栏关闭钮,再点开关钮关闭电路编辑器
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobartask").Window) #任务直接渲染在卡片里,无内层 daqtasks 子窗口
            for (gi, child) in enumerate(qic.taskroot().children) #分组头默认折叠,先展开才能点到组内任务
                child.isgroup && ItemOpen(string("###daqtasks_group", gi))
            end
            for i in 1:5
                SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobartask").Window)
                ItemClick("###task$i")
                SetRef("//Edit Task $i")
                wastext = qic.leafvalues(qic.taskroot())[i].textmode
                wastext && ItemClick(mlstr("Text")) #个别任务以文本模式保存(切换钮标签为 Text):先切到模块模式再走统一流程
                # ItemClick(MORESTYLE.Icons.HoldPin)
                ItemClick(MORESTYLE.Icons.Convert)
                ItemClick(MORESTYLE.Icons.Edit)
                ItemClick(MORESTYLE.Icons.View)
                ItemClick(mlstr("Block"))
                ItemClick(MORESTYLE.Icons.Edit)
                ItemClick(MORESTYLE.Icons.View)
                ItemClick(mlstr("Interpret"))
                ItemClick(mlstr("Anti-interpret"))
                ItemClick(string("//\$FOCUSED/", string(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"))))
                ItemClick(mlstr("Text"))
                wastext && ItemClick(mlstr("Block")) #还原为保存时的文本模式
                # ItemClick(MORESTYLE.Icons.HoldPin)
            end
        end
        ts = []
        push!(ts, @register_test(engine, "QInsControl", "DAQ run task 1"))
        push!(ts, @register_test(engine, "QInsControl", "DAQ run task 2"))
        push!(ts, @register_test(engine, "QInsControl", "DAQ run task 3"))
        push!(ts, @register_test(engine, "QInsControl", "DAQ run task 4"))
        push!(ts, @register_test(engine, "QInsControl", "DAQ run task 5"))
        for i in 1:5
            # i in [2,4, 5] && continue
            ts[i].TestFunc = () -> begin
                qic.closeallwindows() #兜底关闭前序残留窗口(无标题栏窗口 ITE 挪不动)
                SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobartask").Window)
                ItemClick("###task$i", ig.ImGuiMouseButton_Right)
                ItemClick(string("//\$FOCUSED/", string(MORESTYLE.Icons.RunTask, " ", mlstr("Run"))))
                timedwait(() -> (Yield(); false), i == 3 ? 4 : 12)
                SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot").Window)
                if i == 1
                    ItemClick("###plot1")
                elseif i == 4
                    ItemClick("###plot2")
                elseif i == 5
                    ItemClick("###plot1")
                    ItemClick("###plot2")
                end
                SetRef(WindowInfo("//###MainWindow/main/left/queue").Window)
                ItemClick(string(MORESTYLE.Icons.Update, "##update showing plots"))
                # SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot/DataPlots").Window)
                if i == 3
                    SetRef(WindowInfo("//###MainWindow/main/right").Window)
                    ItemClick(MORESTYLE.Icons.Instruments)
                    ItemClick(MORESTYLE.Icons.InstrumentsSetting)
                    SetRef(WindowInfo("//###MainWindow/main/right/right content/border2").Window)
                    ItemOpen("VirtualInstr")
                    ItemOpen("VirtualInstr/VIRTUAL::ADDRESS")
                    ItemClick("VirtualInstr/VIRTUAL::ADDRESS/Demo")
                    SetRef(WindowInfo("//VirtualInstrVIRTUAL::ADDRESSDemo/drawing area").Window)
                    ItemClick("28")
                    while qic.INSTRBUFFERVIEWERS["VirtualInstr"]["VIRTUAL::ADDRESS"].insbuf.quantities["I"].uindex != 3
                        ItemClick("30")
                    end
                    ItemInputValue("32", 0.06)
                    ItemInputValue("33", -1.2)
                    ItemClick("35")
                    timedwait(() -> (Yield(); false), 12)
                    ItemInputValue("33", 1.24)
                    ItemClick("35")
                    timedwait(() -> (Yield(); false), 12)
                    ItemInputValue("33", -1.24)
                    ItemClick("35")
                    timedwait(() -> (Yield(); false), 12)
                    WindowClose("//VirtualInstrVIRTUAL::ADDRESSDemo")
                end
                timedwait(() -> (Yield(); !qic.SYNCSTATES[qic.IsDAQTaskRunning]), 60)
            end
        end

        qic.julia_main(; engine, doexit=false) #不 exit:让 Test 汇总正常打印,进程退出码如实反映测试结果

        #ITE GUI 测试的真实结果:已跑完的测试须全部成功且队列清空(渲染循环崩溃/找不到 item 会残留队列)
        summary = te.GetResultSummary(engine)
        @test summary.CountTested == summary.CountSuccess
        @test summary.CountInQueue == 0
        te.PrintResultSummary(engine)
        te.DestroyContext(engine)
    end # if !GENERATING
end