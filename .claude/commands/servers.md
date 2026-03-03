Manage running Python HTTP servers (started with `python3 -m http.server`).

Use the Bash tool to run: `ps aux | grep "python3 -m http.server" | grep -v grep`

Parse the output to extract each server's PID, port, and directory.

Then follow this logic based on $ARGUMENTS:

- If $ARGUMENTS is empty or "list": Display the running servers in a clean table (PID | Port | Directory). If none are running, say so. Then ask the user with AskUserQuestion if they'd like to kill any of them — present each server as an option (e.g. "Port 8080 — /path/to/dir (PID 1234)") plus a "Never mind" option.

- If $ARGUMENTS starts with "kill": Parse the port number from $ARGUMENTS (e.g. `/servers kill 8080`). Find the process running on that port using `lsof -ti:<port>`, confirm what it is, kill it with `kill <PID>`, and report success or failure.

After killing a server, re-run the list and show updated status.

**Usage:**
```
/servers
/servers list
/servers kill 8080
```
