import CImGui as ig
import QInsControl as qic
import QInsControl: string, mlstr, MORESTYLE
using ImGuiTestEngine
import ImGuiTestEngine as te
import ImGuiTestEngine: WindowInfo, WindowClose, ItemOpen, ItemInputValue
using Test

@testset "QInsControl.jl" begin
    @test qic.JLD2.load(joinpath(@__DIR__, "../example/demo.daq")) isa Dict

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
        for dp in qic.DAQDATAPLOTS
            dp.showplot = false
        end
        qic.WORKPATH = joinpath(@__DIR__, "TestQInsControl")
    end
    @register_test(engine, "QInsControl", "Open Plots") do
        SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot/DataPlots").Window)
        ItemClick("###plot1")
        ItemClick("###plot2")
    end
    @register_test(engine, "QInsControl", "Render Plots") do
        SetRef(WindowInfo("//###MainWindow/main/left/queue").Window)
        ItemClick(string(MORESTYLE.Icons.Update, "##update showing plots"))
    end
    @register_test(engine, "QInsControl", "Close Plots") do
        for dp in qic.DAQDATAPLOTS
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
    for i in 1:5
        # i in [2,4, 5] && continue
        ts[i].TestFunc = () -> begin
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobartask/daqtasks/").Window)
            ItemClick("###task$i", ig.ImGuiMouseButton_Right)
            ItemClick(string("//\$FOCUSED/", string(MORESTYLE.Icons.RunTask, " ", mlstr("Run"))))
            timedwait(() -> (Yield(); false), i == 3 ? 4 : 12)
            SetRef(WindowInfo("//###MainWindow/main/left/queue/scrobarplot/DataPlots").Window)
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