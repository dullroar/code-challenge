# Container image for the Python/Tk entry. Run it with: sandbox/container/run-image.sh --out ./results src/PythonChallenge1
# Nothing to build. The base has Python 3 with Tk, a virtual display (Xvfb) and a screenshot tool, and no pip or
# compiler. The Tk window opens on the virtual display inside the container; the entrypoint screenshots it
# after a few seconds and closes it. The program writes data/ beside itself, so it runs from a private copy.
FROM cc-rt-pytk:local
COPY program.py /app/program.py
ENV CC_RUN="python3 program.py" CC_WORKDIR=/work/run CC_COPY_APP=1 CC_XVFB=1 CC_SCREEN=800x500x24
