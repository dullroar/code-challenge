---
title: "Transition systems and state machines"
chapter: 2
order: 20
---
A transition system is the simplest machine: a set of *states* and a set of allowed *moves* between them. A finite-state machine is the case with a fixed, small number of states. It exists because small machines can be checked completely: you can list every state and every move. Parsers, network protocols, user-interface flows and the insides of regex engines are all built this way. Every entry in this repository can be drawn as a transition system if you ask two questions: what is the state, and what is one step?

- **Use it when:** behavior depends on history in a bounded way, such as "what did I see before?"
- **Avoid it when:** the state is unbounded. A finite machine cannot count matching brackets of any depth. For that you need a stack (see [[stack-machine]]). Also beware of *state explosion*: the number of states can grow faster than you can draw them.

**Read more:**

- [Transition system](https://en.wikipedia.org/wiki/Transition_system) (Wikipedia)
- [Finite-state machine](https://en.wikipedia.org/wiki/Finite-state_machine) (Wikipedia)
