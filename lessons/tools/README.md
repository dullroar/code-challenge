# Tools

| Script | What it does |
| --- | --- |
| [`check-demo.sh`](check-demo.sh) | Checks the *shape* of any entry's output: `DEMO ONLY` marker, hours 10-19, running totals, stopped on the right card, summary line agrees. The acceptance test most [exercises](../exercises.md) use. |
| [`run-in-sandbox.sh`](run-in-sandbox.sh) | Runs any command in the repo's locked-down toolchain container, on a private copy of a folder, with optional `-e NAME=VALUE`. |
| [`verify-exercises.sh`](verify-exercises.sh) | Runs the reference solution of every Docker exercise and prints PASS or FAIL for each. This is how the [answers key](../answers-key.md) was proven. |
| [`verify-windows.ps1`](verify-windows.ps1) | The same for the Windows Sandbox exercises (E1, E2). |

Reference answers that are real programs live in [`../solutions/`](../solutions).
