using Sockets
using Logging
using Makie, AbstractPlotting
using Observables
using Dates
using LazyJSON
using DelimitedFiles

# Enables the socket reading loop.
const INPUT_SOCKET_EN = Node(true)

# Stores the last received string.
const input_string = Node("")

# Stores the parsed vector.
const input_vector = Node(zeros(6))

# latest plot time.
#const lastUpdate = Node(time_ns());

const lastUpdate_ = Node(time_ns());

"""
    servertask()

Create a Task, that creates a socket and reads the incoming messages.

Listens on a given port (on localhost) and after an incoming connection waits for incoming
strings and updates the `rtdestring` `Observable`.
Arguments must be set "from outside", because a Task can't have parameters.

# Arguments
- `SERVER_PORT::Integer`: must be set outside.
- `INPUT_SOCKET_EN::Observable`: can be used to stop the task and close the connection.
"""
function servertask()
    INPUT_SOCKET_EN[] = true
    @info "RTDE server is running on $(getipaddr()):$SERVER_PORT"
    server = listen(ip"127.0.0.1", SERVER_PORT)
    socket = accept(server)
    close(server)
    @info "RTDE server accepted: $(getpeername(socket)[1])."
    while isopen(socket) && INPUT_SOCKET_EN[]
        input_string[] = readline(socket)
    end
    close(socket)
    @info "RTDE socket closed, task finished."
end

const MAX_SIZE = 1250;

FxV = rand(MAX_SIZE);
FyV = rand(MAX_SIZE);
FzV = rand(MAX_SIZE);
TxV = rand(MAX_SIZE);
TyV = rand(MAX_SIZE);
TzV = rand(MAX_SIZE);
tV = rand(MAX_SIZE);

fxNode = Node(FxV);
fyNode = Node(FyV);
fzNode = Node(FzV);
txNode = Node(TxV);
tyNode = Node(TyV);
tzNode = Node(TzV);
tvNode = Node(tV);

s1 = lines(fxNode);
s2 = lines(fyNode);
s3 = lines(fzNode);
s4 = lines(txNode);
s5 = lines(tyNode);
s6 = lines(tzNode);

# put in an array to handle the axes and the limit updates easier
sArr = [s1, s2, s3, s4, s5, s6];
#yArr = ["Fx [N]", "Fy [N]", "Fz [N]", "Tx [Nm]", "Ty [Nm]", "Tz [Nm]"];
yArr = ["$i" for i in 1:6]

scene = vbox(hbox(sArr[3], sArr[2], sArr[1]), hbox(sArr[6], sArr[5], sArr[4]));

for i in 1:6
    sArr[i][Axis][:names][:axisnames] = ("Time", yArr[i]);
end

function pushTo!(A, newX, maxSize)
    if size(A, 1) < maxSize
        push!(A, newX)
    else
        popfirst!(A)
        push!(A, newX)
    end
end

## RTDE getters

"""
    getJSONvalue(str, jsonid)

Get 6 long `Float64` vector from `str` identified by ˙jsonid˙.
"""
function getJSONvalue(str, jsonid)
    try
        jsonD = LazyJSON.value(str)
        input_vector[] = convert(Array{Float64,1}, jsonD[jsonid])
        return true
    catch
        @info "JSON parse error caught: $jsonid; $str"
        return false
    end
end

function updateplotvectors(f)
    pushTo!(FxV, f[1], MAX_SIZE)
    pushTo!(FyV, f[2], MAX_SIZE)
    pushTo!(FzV, f[3], MAX_SIZE)
    pushTo!(TxV, f[4], MAX_SIZE)
    pushTo!(TyV, f[5], MAX_SIZE)
    pushTo!(TzV, f[6], MAX_SIZE)

    # get the current time
    current_time = time_ns()
    # save the time in seconds - not used currently
    ttt = (current_time-startUp)/1000000000
    #pushTo!(tV, ttt, MAX_SIZE)
    lastUpdate_[] = current_time
end

function updatePlot(val)
    fxNode[] = FxV
    fyNode[] = FyV
    fzNode[] = FzV
    txNode[] = TxV
    tyNode[] = TyV
    tzNode[] = TzV
    # update limits:
    for i in 1:6
        AbstractPlotting.update_limits!(sArr[i])
    end
    AbstractPlotting.update!(scene)
end

# Interactivity functions and atomic variables
const JOINT = "actual_q"
const JOINTd = "actual_qd"

update_time = 0.25; # seconds
lastUpdate = throttle(update_time, lastUpdate_)

h_input = on(str->getJSONvalue(str, JOINT), input_string)

h_array = on(updateplotvectors, input_vector)
h_plot = on(updatePlot, lastUpdate)

const isForceArrayUpdating = Threads.Atomic{Bool}(true)
const isSaveRunning = Threads.Atomic{Bool}(false)

function pausePlot(atomic_var)
    newVal = false
    oldVal = Threads.atomic_cas!(atomic_var, true, newVal)
    if oldVal
        off(lastUpdate, h_plot)
        @info "Paused plot."
    else
        @info "Plot is already paused."
    end
end

function restartPlot(atomic_var)
    newVal = true
    oldVal = Threads.atomic_cas!(atomic_var, false, newVal)
    if !oldVal
        h_plot = on(updatePlot, lastUpdate)
        @info "Restarted plot."
    else
        @info "Plot is already running."
    end
end

const saveNameFormat = DateFormat("yyyymmddTHM-S")

function saveForceValues(atomic_var)
    newVal = true
    oldVal = Threads.atomic_cas!(atomic_var, false, newVal)
    if !oldVal
        fname = Dates.format(Dates.now(), saveNameFormat) * ".txt"
        open(fname, "w") do io
            println(io, "1,2,3,4,5,6")
            writedlm(io, zip(fxNode[], fyNode[], fzNode[], txNode[], tyNode[], tzNode[]), ',')
        end
        Threads.atomic_xchg!(atomic_var, false)
        @info "Save finished."
    else
        @info "Another save is running. This request will be voided."
    end
end

#off(lastUpdate, h_plot)
#on(println, lastUpdate)

# Button handling

h_buttons = on(events(scene).keyboardbuttons) do button
    if ispressed(button, Keyboard.s)
        saveForceValues(isSaveRunning)
    elseif ispressed(button, Keyboard.p)
        pausePlot(isForceArrayUpdating)
    elseif ispressed(button, Keyboard.r)
        restartPlot(isForceArrayUpdating)
    elseif ispressed(button, Keyboard.f5)
        updatePlot(lastUpdate[])
    end
end

# Turn off buttons
# off(events(scene).keyboardbuttons, h_buttons)

# servtask = Task(servertask)
# const startUp = time_ns()
# scene
# schedule(servtask)
