// The whole algorithm, as three closures. No I/O, no loop statement, no `this`.
// A closure is a function together with the variables it was made next to. Here those variables are the program's state,
// and the only way to reach them is to call the function.

export const CATEGORIES = ['Meetings', 'Coding', 'Debugging', 'Learning'];

// 1. A source of hours: a closure over one number (Park-Miller). Every call moves `state` and answers 10 to 19.
export const hoursFrom = seed => (state => () => 10 + (state = state * 48271 % 2147483647) % 10)(seed);

// 2. The card machine: a closure over three variables. Every call makes the next card and moves them. After the card
//    that takes the total over the limit it answers undefined, for ever. THE STOP RULE IS the assignment to `over`.
export const machine = nextHours => {
  let n = 0, total = 0, over = false;                    // the captured environment: nothing else can see these
  return () => over ? undefined : (hours => (total += hours, over = total > 40, { category: CATEGORIES[n++ % 4], hours, total }))(nextHours());
};

// 3. The iteration protocol, by hand: an iterable is an object whose [Symbol.iterator]() answers an object with next().
//    next() asks the machine for a card, and says `done` when it has none. A card is made only when something asks for it.
export const cards = next => ({
  [Symbol.iterator]: () => ({ next: () => (card => card ? { value: card, done: false } : { value: undefined, done: true })(next()) }),
});
