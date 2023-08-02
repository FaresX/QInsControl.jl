# Add Instruments

## auto-detect
One can click on **Auto Search** to auto-detect the available instruments in NI MAX. 

![image](assets/auto-detect.png)

## muanully add
Or manually add an instrument through clicking on **Manual Input** after filling the address and clicking on **Add** in
the end. For an instrument that supports TCP/IP protocol, address has to be in the form of **TCPIP::$IP::$PORT::SOCKET**.

![image](assets/manually-add.png)

# Control the Instruments

Once adding instruments finishes, one can click **Instrument Settings and Status** to query the status of specific instrument or set it.
The controllable variables are classified by three types: sweep, set, read. 

## sweep
For the sweepable variables, it can be swept from the present value to the given value with definite step size and delay.

![image](assets/control-sweep.png)

## set
For the settable variables, it can be set by the given value through inputing or simply clicking on a pre-defined optional 
value.

![image](assets/control-set.png)

## read
For the readable variables, it can be only queried.

![image](assets/control-read.png)

All these variables support selecting unit and whether it will auto update the state itself.

# Data Acquiring

Clicking on **Instrument** -> **Data Acquiring** to do data acquiring

![image](assets/DAQ.png)

**Workplace** : select root folder for saving data. Data will be stored as
```
root folder/year/month/day/[time] task name.qdt
```
**Task 1** : represent a task script to aquire data. One can click it to edit the script or right click for more options.

**microchip** : click it to edit circuit for recording measurement configuration.

**Run All** : run all the available tasks in a top-down order

**Pause** : suspend the running task

**Interrupt** : stop the running task

## Edit circuit
![image](assets/circuit.png)
QInsControl provides a simple record manner for circuit in an experiment. For a samplebase, one can right click to load a sample image and then add some pins to match the real configuration and these pins can be dragged to the position in demand. For other nodes, one can easily right click to add or modify to satisfy the specified requirements.

## Edit script
For writing a script with convenience and universality, QInsControl provides several blocks to do this. In general, it is easy to writing an available script with only SweepBlocks and ReadingBlocks. For example

![image](assets/example-easyscript.png)

Here, I drive **A输出电流** of a **K2612** with address **address** (not specified) from its present value to -100 nA with a step 1 nA and a delay 0.1 s. Then, with the same method I drive it to 100 nA. In this process, for each value I drived to I get a reading from two **LI5650** with different address (not specified here). One datum of **DATA** is in the form of "data1,data2" which can be indexed by **1:2** and assigned to two keys **Ix** and **Iy** (or **Vx** and **Vy**). By the way, two ReadingBlocks with green borders means annotation **@async** for faster reading.

### CodeBlock
![image](assets/CodeBlock.png)

It can be input with any julia codes. It is helpful when dealing with complicated relation between variables and it
supports all the grammar of julia language.

### StrideCodeBlock
![image](assets/StrideCodeBlock.png)

It is similar to CodeBlock, but it can only be input a block title codes such as *for end*, *begin end*, *function end* and
so on. It is used to combine block codes in julia with other blocks in QInsControl. Middle click on its icon disables its handler which is used for pausing and interrupting.

### BranchBlock
![image](assets/BranchBlock.png)
It is only used inside a StrideCodeBlock to be complete. For example, it can be filled with *else*, *catch* and so on.

### SweepBlock
![image](assets/SweepBlock.png)

It is used to sweep a sweepable quantity. One can click to select the specific instrument, address and quantity and input step, destination and delay. A sweepable quantity is generally dimensioned and one have to make sure that a 
correct unit is selected.

### SettingBlock
![image](assets/SettingBlock.png)

Similar to SweepBlock but for a settable quantity (a sweepable quantity is also a settable quantity). One can input a
string or a number dependent on the unit. When unit type is none, it only supports a string input and a "$" symbol is
able to be used to interpolate like in julia. Moreover, middle click at region of set value will open an optional values list for convenience.

### ReadingBlock
![image](assets/ReadingBlock.png)

*Index* is used to split the data by ",". When data do not include delimiter, leave it blank. *mark* is used to name the 
recorded data. When data format includes delimiter, one can use "," to seperate multiple marks which is also unnecessary.

### LogBlock
![image](assets/LogBlock.png)

When it is executed, all the available instruments will be logged. (before and after script runing, a logging action 
will happen, so it is not necessary to add this block in the first and last line of a script)

### WriteBlock
![image](assets/WriteBlock.png)

Input the command and write to the specified instrument.

### QueryBlock
![image](assets/QueryBlock.png)

Input the command and query the specified instrument.

### ReadBlock
![image](assets/ReadBlock.png)

Read the specified instrument.

### SaveBlock
![image](assets/SaveBlock.png)

It is used to save a variable defined in the context. *mark* is an optional input to specify the name to be stored. When
it is blank, the name will be the same as the variable.

## note
All the blocks that bind to a specified instrument can be middle clicked to enter catch mode. In this mode, the icon is 
red and the data obtained will be a "" when an error occurs. For ReadingBlock, QueryBlock and ReadBlock, middle clicking
at the region used to input marks will change the mode from normal to observable to observable and readable. In 
observable mode, the mark region is cyan and the obtained data will be stored in a variable named by the input marks
and will not be stored in file. In observable and readable region, the mark region is red, all same as observable mode
but the obtained data will stored in file. For ReadingBlock, WriteBlock, QueryBlock and ReadBlock, clicking on the block
border will enter the async mode. In this mode, block border is green and the generated codes will be marked by @async,
this almost always speeds up the measurement.
Different mode has different color indicator which can be found in **File** -> **Preferences** -> **Style** -> **More Style**. Furthermore, this editor supports dragging to reorder blocks and a Ctrl down to dragging a block into a StrideCodeBlock or SweepBlock.

## Example
![image](assets/example-script.png)

This panel includes a title of the editing task, a **HOLD** checkbox to set the panel no-close when selected, an inputable
region to record something necessary, a button **Refresh Instrument list** with the same functionality as previous menu, an **Edit** or 
**View** checkbox to change the editing mode and finally a region to write your own script.

This script includes two loop structures. The outter one is constructed by a StrideCodeBlock with code
```julia
@progress for i in 1:2
```
on it. The macro @progress is used to show a progressbar. The inner one is constructed by a SweepBlock. It relates to
the instrument VirtualInstr with address VirtualAddress, variable "扫描测试", step 1 μA, destination 200 μA and delay 
0.1s for each loop.

In general, it is unnecessary to write such a complicated script. Most of them are used to support special demands and ensure universality.

## plot data
![image](assets/select-plot.png)

One can right click at blank region to select plots to show.

![image](assets/select-data-plot.png)

The data used to plot includes four dimensions X Y Z W. X Y Z is regular dimensions and W is used to be calculated with others. To plot a heatmap, a matrix is necessay but the stored data format is as a vector so that it has to be specified
the dimensions of the Z plotting matrix and reverse it in dimension 1 or 2. At the bottom region, one can do some simple
data processing, and the selected data have bind to variables x, ys, z, ws. For Y and W dimension, they relate to
variables ys and ws respectively and can be accessed by index. For convenience, ys[1] and ws[1] is simply y and w.

One can middle click or right click at plot region to find more options.

## project
All elements above together make up one project. One can save and load a project to conveniently reuse scripts, circuit,
and plots. One example file [demo.daq](../../example) can be found in example folder.

# Data Reviewing

Click on **File** -> **Open File** (**Open Folder**) to open saved files. Here One can review the content stored in the file
includes the states of instruments, the script, the circuit, the data and the plots. Right click on the tabbar **Plots**
can modify the plots.