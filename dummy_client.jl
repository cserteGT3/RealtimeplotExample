using Sockets
using Logging

"""
    clienttask()

Create a Task, that connects to a server on localhost.

# Arguments
- `SERVER_PORT::Integer`: must be set outside.
- `sleeptime::Float64`: must be set outside.
"""
function clienttask()
    @info "Connecting to $(getipaddr()):$SERVER_PORT"
    socket = connect(ip"127.0.0.1", SERVER_PORT)
    @info "Client connected: $(getpeername(socket)[1])."

    msgstart = "{\"actual_q\": "
    msgmid = ", \"actual_qd\": "
    msgend = "}"
    a1 = 100 .*rand(12)
    while isopen(socket) && client_enabled
        println(socket, msgstart, a1[1:6], msgmid, a1[7:12], msgend)
        a1 = 100 .*rand(12)
        sleep(sleeptime)
    end
    close(socket)
    @info "Client socket closed, task finished."
end

SERVER_PORT = 4000
sleeptime = 1
client_enabled = true

client_task = Task(clienttask)
schedule(client_task)

# shut down with:
# client_enabled = false
