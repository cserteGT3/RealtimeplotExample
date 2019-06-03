using Pkg
Pkg.activate(".")

include("dummy_client.jl")
include("plotting_server.jl")

# setup client
SERVER_PORT = 4002
sleeptime = 1
client_enabled = true
client_task = Task(clienttask)

servtask = Task(servertask)
const startUp = time_ns()
schedule(servtask)

# scene
#schedule(client_task)
