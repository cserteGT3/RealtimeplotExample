using Sockets
using Logging
using Makie, AbstractPlotting
using Observables
using Dates
using LazyJSON
using DelimitedFiles

# Stores the last received string.
const input_string = Node("")

# Stores the parsed vector.
const input_vector = Node(zeros(6))

# latest plot time. it's value is not used
const lastUpdate_ = Node(time_ns());

# throttle plot updates to 4 times/second
lastUpdate = throttle(0.25, lastUpdate_)

const startUp = time_ns()

# at a 125Hz this means the last 10 seconds
const MAX_SIZE = 1250;

# 6 arrays for the 6 subplots
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
yArr = ["$i" for i in 1:6]

scene = vbox(hbox(sArr[3], sArr[2], sArr[1]), hbox(sArr[6], sArr[5], sArr[4]));

for i in 1:6
    sArr[i][Axis][:names][:axisnames] = ("Time", yArr[i]);
end

# this function makes a "fix sized" array
function pushTo!(A, newX, maxSize)
    if size(A, 1) < maxSize
        push!(A, newX)
    else
        popfirst!(A)
        push!(A, newX)
    end
end

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

# this called every time when a new message is parsed
# updates the vectors (not the observables)
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

    # lastUpdate_ is used to trigger further updates (but it is throttled down)
    lastUpdate_[] = current_time
end

# this function updates the observables (= the plot itself)
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

# JSON names
const JOINT = "actual_q"
const JOINTd = "actual_qd"

# process the input string
h_input = on(str->getJSONvalue(str, JOINT), input_string)

# when an input string is processed, update the vectors
h_array = on(updateplotvectors, input_vector)
# when the throttled observable updates, update the plot
h_plot = on(updatePlot, lastUpdate)


############################
# Begin buttons code       #
# You can ignore this part #
############################

# Interactivity functions and atomic variables
# These are for the buttons: p, r, s
# atomic variables are used to keep the state consistent

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

####################
# End buttons code #
####################


# iterations number of new values with sleep(sleep_time) between
function newvalues(iterations, sleep_time = 0.01)
    msgstart = "{\"actual_q\": "
    msgmid = ", \"actual_qd\": "
    msgend = "}"
    a1 = rand(12)

    λ = 100 .*rand(12)
    i = 0
    for i in 1:iterations
        input_string[] = msgstart * string(a1[1:6]) * msgmid * string(a1[7:12]) * msgend
        sleep(sleep_time)

        a1 = rand(12)

        if i > 1300
            λ = 100 .*rand(12)
            i = 0
        end
        i +=1
    end
end
