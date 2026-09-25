import CImGui as ig
import QInsControl as qic
import QInsControl: string, mlstr, MORESTYLE
using ImGuiTestEngine
import ImGuiTestEngine as te
import ImGuiTestEngine: WindowInfo, WindowClose, ItemOpen, ItemInputValue
using Test

@testset "QInsControl.jl" begin
    @test qic.JLD2.load(joinpath(@__DIR__, "../example/demo.daq")) isa Dict

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
        #旧版树形工程（DAQTaskNode）→ 新版 Tree{DAQTask} 迁移
        old = qic.JLD2.load(joinpath(@__DIR__, "../example/demo.daq"), "daqtasks")
        if old isa qic.DAQTaskNode
            migrated = qic.Tree{qic.DAQTask}(old)
            nleaves = sum(c.isgroup ? length(c.children) : 1 for c in old.children)
            @test migrated isa qic.Tree{qic.DAQTask}
            @test length(qic.leafvalues(migrated)) == nleaves
        end
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

    engine = te.CreateContext(; exit_on_completion=isempty(ARGS))
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
                    ItemClick("edit confs and widgets/Widget $i")
                end
            end
        end
        SetRef(WindowInfo("//###ins reg/Toolbar").Window)
        ItemClick(string(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"), "##qtcf to toml"))
        WindowClose("//###ins reg")
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
                        WindowClose("//\$FOCUSED")
                        if haskey(qic.INSWCONF, ins)
                            for w in qic.INSWCONF[ins]
                                ItemClick(string("$ins/$addr/", w.name))
                                WindowClose("//\$FOCUSED")
                            end
                        end
                    end
                end
            end
        end
    end
    @register_test(engine, "QInsControl", "Console") do
        SetRef(WindowInfo("//###MainWindow/main/right").Window)
        ItemClick(MORESTYLE.Icons.Help)
        ItemClick(MORESTYLE.Icons.Console)
        WindowClose("//\$FOCUSED")
    end
    @register_test(engine, "QInsControl", "Metrics") do
        SetRef(WindowInfo("//###MainWindow/main/right").Window)
        ItemClick(MORESTYLE.Icons.Help)
        ItemClick(MORESTYLE.Icons.Metrics)
        WindowClose("//\$FOCUSED")
    end
    @register_test(engine, "QInsControl", "Logger") do
        SetRef(WindowInfo("//###MainWindow/main/right").Window)
        ItemClick(MORESTYLE.Icons.Help)
        ItemClick(MORESTYLE.Icons.Logger)
        WindowClose("//\$FOCUSED")
    end
    @register_test(engine, "QInsControl", "ShowAbout") do
        SetRef(WindowInfo("//###MainWindow/main/right").Window)
        ItemClick(MORESTYLE.Icons.Help)
        ItemClick(MORESTYLE.Icons.About)
        ItemClick(string("//\$FOCUSED/", string(mlstr("Confirm"), "##ShowAbout")))
    end
    @register_test(engine, "QInsControl", "Debugger") do
        qic.debugger()
        SetRef("//Debugger")
        OpenAndClose("Global Variables") do 
            OpenAndClose(()->(), "Global Variables/SYNCSTATES")
            OpenAndClose(()->(), "Global Variables/STATES")
            OpenAndClose(()->(), "Global Variables/Tasks")
            OpenAndClose(()->(), "Global Variables/###DATABUF")
            OpenAndClose(()->(), "Global Variables/###DATABUFPARSED")
            OpenAndClose(()->(), "Global Variables/###PROGRESSLIST")
            OpenAndClose(()->(), "Global Variables/###STYLES")
            OpenAndClose(()->(), "Global Variables/###MLSTRINGS")
            OpenAndClose(()->(), "Global Variables/###STATICSTRINGS")
            OpenAndClose(()->(), "Global Variables/###IMAGES")
            OpenAndClose(()->(), "Global Variables/###Textures")
            OpenAndClose(()->(), "Global Variables/###FIGURES")
            OpenAndClose(()->(), "Global Variables/###ImMakieFigures")
        end
        WindowClose("//\$FOCUSED")
    end
    tsetup = @register_test(engine, "QInsControl", "DAQ setup")
    tsetup.GuiFunc = () -> begin
        qic.loadproject(joinpath(@__DIR__, "../example/demo.daq"))
        for dp in qic.plotleaves(qic.DAQDATAPLOTS)  # 树形化后经 plotleaves 取叶子
            dp.showplot = false
        end
        qic.WORKPATH = joinpath(@__DIR__, "TestQInsControl")
    end
    @register_test(engine, "QInsControl", "Open Plots") do
        SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot/DAQPlotTree").Window)
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
        SetRef(WindowInfo("//###MainWindow/Toolbar").Window)
        ItemClick(string(MORESTYLE.Icons.Circuit, "##circuit"))
        WindowClose("//\$FOCUSED")
        for i in 1:5
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobartask/daqtasks/").Window)
            ItemClick("###task$i")
            SetRef("//Edit Task $i")
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
            # ItemClick(MORESTYLE.Icons.HoldPin)
        end
    end
    ts = []
    push!(ts, @register_test(engine, "QInsControl", "DAQ run task 1"))
    push!(ts, @register_test(engine, "QInsControl", "DAQ run task 2"))
    push!(ts, @register_test(engine, "QInsControl", "DAQ run task 3"))
    push!(ts, @register_test(engine, "QInsControl", "DAQ run task 4"))
    push!(ts, @register_test(engine, "QInsControl", "DAQ run task 5"))
    for i in 1:1
        # i in [2,4, 5] && continue
        ts[i].TestFunc = () -> begin
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobartask/daqtasks/").Window)
            ItemClick("###task$i", ig.ImGuiMouseButton_Right)
            ItemClick(string("//\$FOCUSED/", string(MORESTYLE.Icons.RunTask, " ", mlstr("Run"))))
            timedwait(() -> (Yield(); false), i == 3 ? 4 : 12)
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot/DAQPlotTree").Window)
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

    qic.julia_main(; engine)

    te.DestroyContext(engine)
end