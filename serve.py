import subprocess
from livereload import Server


def build():
    subprocess.run(["zensical", "build"], check=True)


build()  # initial build on startup

server = Server()
server.watch("docs/", build)
server.watch("zensical.toml", build)
server.serve(root="site", port=8000, host="0.0.0.0")
