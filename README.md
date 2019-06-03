# RealtimeplotExample
Working on real time plotting with Julia and Makie.

## Goals

The main goal is real time plotting of some values parsed from a JSON string, which we get via TCP.
Different values are in the JSON, but the value is always a 6 long array of real numbers.
The frequency of getting the values is around 125 Hz.

I want to pause/restart plotting and also to save the plotted variables.
Pausing the plot means here to not update the plot.
Meanwhile receiving the new values should not stop.
The following buttons work:
* `p`: pause plot.
* `r`: restart plot.
* `s`: saving the variables.

Would be nice of it would work for different JSONs.
For that, later I would use command-line arguments (probably).

## Code

```julia
msgstart = "{\"actual_q\": "
msgmid = ", \"actual_qd\": "
msgend = "}"
a1 = rand(12)

λ = 100 .*rand(12)
i = 0
while isopen(socket) && client_enabled
    println(socket, msgstart, a1[1:6], msgmid, a1[7:12], msgend)
    a1 = rand(12) .*λ

    if i > 1300
        λ = 100 .*rand(12)
        i = 0
    end
    i +=1
    sleep(sleeptime)
end
```
This part of the code scales the values to simulate the changing values.
This is needed because it's possible that we get values that are out of the current range.
For 1300 iterations the same `λ` is used, because the plot is "1250 wide".
On the example picture this can be seen at around x=900.

![](example.png)

## How to use

Clone the repo, and `cd` into it. Then:
```
C:\Users\cstamas\Documents\GIT\RealtimeplotExample>julia --project
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.1.1 (2019-05-16)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> include("src/run.jl")
[ Info: RTDE server is running on 10.1.1.135:4002
Task (runnable) @0x0000000011329fb0

julia> scene

julia> schedule(client_task)
[ Info: Connecting to 10.1.1.135:4002
Task (runnable) @0x0000000011329cd0[ Info: Client connected: 127.0.0.1.

[ Info: RTDE server accepted: 127.0.0.1.

julia> sleeptime = 0.01
0.01
```

You can set `sleeptime` while it's running, it controls how long the client sleeps before sending the next message.
`scene` is ran before starting the client task because I want to wait until the Makie scene is shown.

## Problems/questions

* One of my problems is that everything is global variable, because I couldn't find another way to do this. I feel this fragile.
* Should I use other data structure (for example [CircularBuffer](http://juliacollections.github.io/DataStructures.jl/latest/circ_buffer.html)) instead of `push/pop` to native arrays? (I should probably benchmark it.)
